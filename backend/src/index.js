import express from "express";
import dotenv from "dotenv";
import { calculateBenefit } from "./services/benefitCalculation.service.js";
import { createSnapSpenderOperator } from "./services/snapSpenderOperator.service.js";

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

      const operator = createSnapSpenderOperator({
        ethers,
        provider,
        wallet,
        spender,
        usdc,
        spenderAddr,
      });

      const defaultExpiry =
        process.env.POST_VERIFICATION_USER_EXPIRY === undefined ||
        process.env.POST_VERIFICATION_USER_EXPIRY === ""
          ? 0
          : Number(process.env.POST_VERIFICATION_USER_EXPIRY);

      function sendPostVerificationError(res, status, error) {
        sendJson(res, { success: false, error }, status);
      }

      app.post("/api/post-verification/process", async (req, res) => {
        try {
          const body = req.body ?? {};
          const { walletAddress, householdSize, monthlyIncome, verification } = body;

          if (!walletAddress || typeof walletAddress !== "string") {
            return sendPostVerificationError(res, 400, "invalid_wallet_address");
          }
          if (!ethers.isAddress(walletAddress)) {
            return sendPostVerificationError(res, 400, "invalid_wallet_address");
          }

          const hs = Number(householdSize);
          if (!Number.isInteger(hs) || hs < 1) {
            return sendPostVerificationError(res, 400, "invalid_household_size");
          }

          if (monthlyIncome === undefined || monthlyIncome === null) {
            return sendPostVerificationError(res, 400, "invalid_monthly_income");
          }
          const inc = Number(monthlyIncome);
          if (!Number.isFinite(inc)) {
            return sendPostVerificationError(res, 400, "invalid_monthly_income");
          }

          if (!verification || typeof verification !== "object") {
            return sendPostVerificationError(res, 400, "missing_verification");
          }
          if (verification.verified !== true) {
            return sendPostVerificationError(res, 400, "verification_required");
          }

          let calc;
          try {
            calc = calculateBenefit(inc, hs);
          } catch {
            return sendPostVerificationError(res, 400, "invalid_household_size");
          }

          const checksumUser = ethers.getAddress(walletAddress);

          if (!calc.eligible || calc.benefitDollars === 0) {
            return sendJson(res, {
              success: true,
              walletAddress: checksumUser,
              verificationAccepted: true,
              funded: false,
              reason: "Calculated benefit is 0",
              householdSize: calc.householdSize,
              monthlyIncome: calc.monthlyIncome,
              maxBenefitDollars: calc.maxBenefitDollars,
              benefitDollars: calc.benefitDollars,
              benefitUsdcBaseUnits: calc.benefitUsdcBaseUnits,
            });
          }

          const amountAtomic = calc.benefitUsdcBaseUnits;
          const expiryTs =
            body.expiryTimestamp !== undefined && body.expiryTimestamp !== null
              ? body.expiryTimestamp
              : defaultExpiry;

          const { eligibilityTx, allowanceTx } = await operator.approveUserEligibilityAndAllowance(
            checksumUser,
            amountAtomic,
            expiryTs,
          );
          const depositTx = await operator.depositProgramFunds(amountAtomic);

          const status = await operator.getUserFundingStatus(checksumUser);

          return sendJson(res, {
            success: true,
            walletAddress: checksumUser,
            verificationAccepted: true,
            funded: true,
            householdSize: calc.householdSize,
            monthlyIncome: calc.monthlyIncome,
            maxBenefitDollars: calc.maxBenefitDollars,
            benefitDollars: calc.benefitDollars,
            benefitUsdcBaseUnits: calc.benefitUsdcBaseUnits,
            onchainStatus: {
              eligible: Boolean(status.eligible),
              allowance: status.allowance,
              spent: status.spent,
              remaining: status.remaining,
            },
            txHashes: {
              setEligibility: eligibilityTx.hash,
              setAllowance: allowanceTx.hash,
              depositBenefits: depositTx.hash,
            },
          });
        } catch (e) {
          console.error(e);
          sendPostVerificationError(res, 500, "internal_error");
        }
      });

      app.post("/api/benefits/approve-user", async (req, res) => {
        try {
          const { userAddress, allowanceAtomic, expiryTimestamp } = req.body ?? {};
          if (!userAddress || allowanceAtomic === undefined) {
            return sendJson(res, { error: "userAddress and allowanceAtomic required" }, 400);
          }
          if (!ethers.isAddress(userAddress)) {
            return sendJson(res, { error: "invalid address" }, 400);
          }

          const { eligibilityTx, allowanceTx } = await operator.approveUserEligibilityAndAllowance(
            userAddress,
            allowanceAtomic,
            expiryTimestamp,
          );

          sendJson(res, {
            ok: true,
            eligibilityTxHash: eligibilityTx.hash,
            allowanceTxHash: allowanceTx.hash,
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

          const tx = await operator.depositProgramFunds(amountAtomic);
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
          const tx = await operator.runOperatorTxs(async () => {
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

          const status = await operator.getUserFundingStatus(userAddress);

          sendJson(res, {
            userAddress: status.userAddress,
            eligible: status.eligible,
            allowanceAtomic: status.allowance,
            spentAtomic: status.spent,
            remainingAtomic: status.remaining,
            expiryTimestamp: status.expiryTimestamp,
            paused: status.paused,
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
