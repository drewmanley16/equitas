import express from "express";
import dotenv from "dotenv";

dotenv.config();
// ethers is dynamically imported in listen() so the HTTP server binds before the heavy/ethers bundle loads.

const SNAP_SPENDER_ABI = [
  "function approvedMerchants(address) view returns (bool)",
  "function approvedUsers(address) view returns (bool)",
  "function userAllowance(address) view returns (uint256)",
  "function userSpent(address) view returns (uint256)",
  "function userExpiry(address) view returns (uint256)",
  "function paused() view returns (bool)",
  "function setMerchant(address merchant, bool approved)",
  "function setUserEligibility(address user, bool eligible, uint256 expiryTimestamp)",
  "function setUserAllowance(address user, uint256 allowance)",
  "function depositBenefits(uint256 amount)",
  "function payMerchant(address merchant, uint256 amount)",
];

const ERC20_ABI = [
  "function approve(address spender, uint256 amount) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)",
];

function requireEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env: ${name}`);
  return v;
}

/** Avoid Express `res.json` / `res.type` — they call `mime.charsets.lookup`, which breaks when `send.mime` is undefined under ESM + dynamic import. */
function sendJson(res, data, statusCode = 200) {
  res.statusCode = statusCode;
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.end(JSON.stringify(data));
}

const app = express();
let benefitsRoutesMounted = false;
app.use(express.json());

app.get("/api/health", (_req, res) => {
  sendJson(res, { ok: true, service: "equitas-benefits-api" });
});

const port = Number(process.env.PORT ?? 3000);
const host = process.env.BIND_HOST ?? "127.0.0.1";

app.listen(port, host, () => {
  console.log(`Benefits API on http://${host}:${port}`);

  // Defer ethers so the `listen` callback returns before ethers loads.
  setImmediate(() => {
    void (async () => {
      if (benefitsRoutesMounted) return;
      benefitsRoutesMounted = true;

      const { ethers } = await import("ethers");

      const rpcUrl = requireEnv("RPC_URL");
      const operatorKey = requireEnv("OPERATOR_PRIVATE_KEY");
      const spenderAddr = requireEnv("SNAP_SPENDER_ADDRESS");
      const usdcAddr = requireEnv("USDC_ADDRESS");

      const chainId = Number(process.env.CHAIN_ID ?? 31337);
      const provider = new ethers.JsonRpcProvider(rpcUrl, chainId);
      const wallet = new ethers.Wallet(operatorKey, provider);
      const spender = new ethers.Contract(spenderAddr, SNAP_SPENDER_ABI, wallet);
      const usdc = new ethers.Contract(usdcAddr, ERC20_ABI, wallet);

      /** Serialize operator txs — avoids duplicate broadcasts / nonce races under parallel requests. */
      let operatorChain = Promise.resolve();
      function runOperatorTxs(fn) {
        const next = operatorChain.then(() => fn());
        operatorChain = next.catch(() => {});
        return next;
      }

      const opNonce = () => provider.getTransactionCount(wallet.address, "latest");

      app.post("/api/benefits/approve-user", async (req, res) => {
        try {
          const { userAddress, allowanceAtomic, expiryTimestamp } = req.body ?? {};
          if (!userAddress || allowanceAtomic === undefined) {
            return sendJson(res, { error: "userAddress and allowanceAtomic required" }, 400);
          }
          const expiry =
            expiryTimestamp === undefined || expiryTimestamp === null
              ? 0
              : BigInt(String(expiryTimestamp));

          const { tx1, tx2 } = await runOperatorTxs(async () => {
            const n = await opNonce();
            const t1 = await spender.setUserEligibility(userAddress, true, expiry, { nonce: n });
            await t1.wait();
            const t2 = await spender.setUserAllowance(userAddress, BigInt(String(allowanceAtomic)), {
              nonce: n + 1,
            });
            await t2.wait();
            return { tx1: t1, tx2: t2 };
          });

          sendJson(res, {
            ok: true,
            eligibilityTxHash: tx1.hash,
            allowanceTxHash: tx2.hash,
          });
        } catch (e) {
          console.error(e);
          sendJson(res, { error: e.shortMessage ?? e.message ?? String(e) }, 500);
        }
      });

      app.post("/api/benefits/deposit", async (req, res) => {
        try {
          const { amountAtomic } = req.body ?? {};
          if (amountAtomic === undefined) {
            return sendJson(res, { error: "amountAtomic required" }, 400);
          }
          const amount = BigInt(String(amountAtomic));

          const tx = await runOperatorTxs(async () => {
            const current = await usdc.allowance(wallet.address, spenderAddr);
            if (current < amount) {
              const n = await opNonce();
              const approveTx = await usdc.approve(spenderAddr, ethers.MaxUint256, { nonce: n });
              await approveTx.wait();
              const dep = await spender.depositBenefits(amount, { nonce: n + 1 });
              await dep.wait();
              return dep;
            }
            const dep = await spender.depositBenefits(amount, { nonce: await opNonce() });
            await dep.wait();
            return dep;
          });
          sendJson(res, { ok: true, txHash: tx.hash });
        } catch (e) {
          console.error(e);
          sendJson(res, { error: e.shortMessage ?? e.message ?? String(e) }, 500);
        }
      });

      app.post("/api/benefits/setup-merchant", async (req, res) => {
        try {
          const { merchantAddress, approved } = req.body ?? {};
          if (!merchantAddress || approved === undefined) {
            return sendJson(res, { error: "merchantAddress and approved required" }, 400);
          }
          const tx = await runOperatorTxs(async () => {
            const t = await spender.setMerchant(merchantAddress, Boolean(approved));
            await t.wait();
            return t;
          });
          sendJson(res, { ok: true, txHash: tx.hash });
        } catch (e) {
          console.error(e);
          sendJson(res, { error: e.shortMessage ?? e.message ?? String(e) }, 500);
        }
      });

      app.post("/api/benefits/pay-merchant", async (req, res) => {
        try {
          const beneficiaryKey = process.env.BENEFICIARY_PRIVATE_KEY;
          if (!beneficiaryKey) {
            return sendJson(
              res,
              {
                error:
                  "BENEFICIARY_PRIVATE_KEY not set — add for demo pay flow or sign payMerchant on-device",
              },
              501,
            );
          }
          const { merchantAddress, amountAtomic } = req.body ?? {};
          if (!merchantAddress || amountAtomic === undefined) {
            return sendJson(res, { error: "merchantAddress and amountAtomic required" }, 400);
          }
          const userWallet = new ethers.Wallet(beneficiaryKey, provider);
          const userSpender = spender.connect(userWallet);
          const tx = await userSpender.payMerchant(merchantAddress, BigInt(String(amountAtomic)));
          await tx.wait();
          sendJson(res, { ok: true, txHash: tx.hash });
        } catch (e) {
          console.error(e);
          sendJson(res, { error: e.shortMessage ?? e.message ?? String(e) }, 500);
        }
      });

      app.get("/api/benefits/status/:userAddress", async (req, res) => {
        try {
          const { userAddress } = req.params;
          if (!ethers.isAddress(userAddress)) {
            return sendJson(res, { error: "invalid address" }, 400);
          }

          const [eligible, allowance, spent, expiry, paused] = await Promise.all([
            spender.approvedUsers(userAddress),
            spender.userAllowance(userAddress),
            spender.userSpent(userAddress),
            spender.userExpiry(userAddress),
            spender.paused(),
          ]);

          const allowanceBn = BigInt(allowance.toString());
          const spentBn = BigInt(spent.toString());
          const remaining = allowanceBn > spentBn ? allowanceBn - spentBn : 0n;

          sendJson(res, {
            userAddress,
            eligible,
            allowanceAtomic: allowance.toString(),
            spentAtomic: spent.toString(),
            remainingAtomic: remaining.toString(),
            expiryTimestamp: expiry.toString(),
            paused,
          });
        } catch (e) {
          console.error(e);
          sendJson(res, { error: e.shortMessage ?? e.message ?? String(e) }, 500);
        }
      });

      console.log("Benefits routes registered (ethers ready).");
    })();
  });
});
