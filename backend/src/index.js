import express from "express";
import dotenv from "dotenv";
import { ethers } from "ethers";

dotenv.config();

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

const app = express();
app.use(express.json());

const rpcUrl = requireEnv("RPC_URL");
const operatorKey = requireEnv("OPERATOR_PRIVATE_KEY");
const spenderAddr = requireEnv("SNAP_SPENDER_ADDRESS");
const usdcAddr = requireEnv("USDC_ADDRESS");

const provider = new ethers.JsonRpcProvider(rpcUrl);
const wallet = new ethers.Wallet(operatorKey, provider);
const spender = new ethers.Contract(spenderAddr, SNAP_SPENDER_ABI, wallet);
const usdc = new ethers.Contract(usdcAddr, ERC20_ABI, wallet);

app.post("/api/benefits/approve-user", async (req, res) => {
  try {
    const { userAddress, allowanceAtomic, expiryTimestamp } = req.body ?? {};
    if (!userAddress || allowanceAtomic === undefined) {
      return res.status(400).json({ error: "userAddress and allowanceAtomic required" });
    }
    const expiry =
      expiryTimestamp === undefined || expiryTimestamp === null
        ? 0
        : BigInt(String(expiryTimestamp));

    const tx1 = await spender.setUserEligibility(userAddress, true, expiry);
    await tx1.wait();

    const tx2 = await spender.setUserAllowance(userAddress, BigInt(String(allowanceAtomic)));
    await tx2.wait();

    res.json({
      ok: true,
      eligibilityTxHash: tx1.hash,
      allowanceTxHash: tx2.hash,
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.shortMessage ?? e.message ?? String(e) });
  }
});

app.post("/api/benefits/deposit", async (req, res) => {
  try {
    const { amountAtomic } = req.body ?? {};
    if (amountAtomic === undefined) {
      return res.status(400).json({ error: "amountAtomic required" });
    }
    const amount = BigInt(String(amountAtomic));

    const current = await usdc.allowance(wallet.address, spenderAddr);
    if (current < amount) {
      const approveTx = await usdc.approve(spenderAddr, ethers.MaxUint256);
      await approveTx.wait();
    }

    const tx = await spender.depositBenefits(amount);
    await tx.wait();
    res.json({ ok: true, txHash: tx.hash });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.shortMessage ?? e.message ?? String(e) });
  }
});

app.post("/api/benefits/setup-merchant", async (req, res) => {
  try {
    const { merchantAddress, approved } = req.body ?? {};
    if (!merchantAddress || approved === undefined) {
      return res.status(400).json({ error: "merchantAddress and approved required" });
    }
    const tx = await spender.setMerchant(merchantAddress, Boolean(approved));
    await tx.wait();
    res.json({ ok: true, txHash: tx.hash });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.shortMessage ?? e.message ?? String(e) });
  }
});

/// Demo-only: submits payMerchant as the beneficiary (no on-device signer). Not for production.
app.post("/api/benefits/pay-merchant", async (req, res) => {
  try {
    const beneficiaryKey = process.env.BENEFICIARY_PRIVATE_KEY;
    if (!beneficiaryKey) {
      return res.status(501).json({
        error: "BENEFICIARY_PRIVATE_KEY not set — add for demo pay flow or sign payMerchant on-device",
      });
    }
    const { merchantAddress, amountAtomic } = req.body ?? {};
    if (!merchantAddress || amountAtomic === undefined) {
      return res.status(400).json({ error: "merchantAddress and amountAtomic required" });
    }
    const userWallet = new ethers.Wallet(beneficiaryKey, provider);
    const userSpender = spender.connect(userWallet);
    const tx = await userSpender.payMerchant(merchantAddress, BigInt(String(amountAtomic)));
    await tx.wait();
    res.json({ ok: true, txHash: tx.hash });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.shortMessage ?? e.message ?? String(e) });
  }
});

app.get("/api/benefits/status/:userAddress", async (req, res) => {
  try {
    const { userAddress } = req.params;
    if (!ethers.isAddress(userAddress)) {
      return res.status(400).json({ error: "invalid address" });
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

    res.json({
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
    res.status(500).json({ error: e.shortMessage ?? e.message ?? String(e) });
  }
});

const port = Number(process.env.PORT ?? 8787);
app.listen(port, () => {
  console.log(`Benefits API on http://127.0.0.1:${port}`);
});
