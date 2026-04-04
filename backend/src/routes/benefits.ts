import { Router, Request, Response } from 'express';
import { ethers } from 'ethers';

const router = Router();

const SNAP_SPENDER_ABI = [
  'function approvedMerchants(address) view returns (bool)',
  'function approvedUsers(address) view returns (bool)',
  'function userAllowance(address) view returns (uint256)',
  'function userSpent(address) view returns (uint256)',
  'function userExpiry(address) view returns (uint256)',
  'function paused() view returns (bool)',
  'function setMerchant(address merchant, bool approved)',
  'function setUserEligibility(address user, bool eligible, uint256 expiryTimestamp)',
  'function setUserAllowance(address user, uint256 allowance)',
  'function depositBenefits(uint256 amount)',
  'function payMerchant(address merchant, uint256 amount)',
];

const ERC20_ABI = [
  'function approve(address spender, uint256 amount) returns (bool)',
  'function allowance(address owner, address spender) view returns (uint256)',
];

function getContracts() {
  const rpcUrl     = process.env.RPC_URL;
  const operatorKey  = process.env.OPERATOR_PRIVATE_KEY;
  const spenderAddr  = process.env.SNAP_SPENDER_ADDRESS;
  const usdcAddr     = process.env.USDC_ADDRESS;

  if (!rpcUrl || !operatorKey || !spenderAddr || !usdcAddr) {
    return null;
  }

  const chainId  = Number(process.env.CHAIN_ID ?? 31337);
  const provider = new ethers.JsonRpcProvider(rpcUrl, chainId);
  const wallet   = new ethers.Wallet(operatorKey, provider);
  const spender  = new ethers.Contract(spenderAddr, SNAP_SPENDER_ABI, wallet) as any;
  const usdc     = new ethers.Contract(usdcAddr, ERC20_ABI, wallet) as any;
  return { provider, wallet, spender, usdc, spenderAddr };
}

// Serialize operator txs to avoid nonce races
let operatorChain = Promise.resolve<any>(undefined);
function runOperatorTxs<T>(fn: () => Promise<T>): Promise<T> {
  const next = operatorChain.then(() => fn());
  operatorChain = next.catch(() => {});
  return next;
}

// POST /api/benefits/approve-user
router.post('/approve-user', async (req: Request, res: Response) => {
  const ctx = getContracts();
  if (!ctx) return res.status(501).json({ error: 'Benefits contracts not configured (set RPC_URL, OPERATOR_PRIVATE_KEY, SNAP_SPENDER_ADDRESS, USDC_ADDRESS)' });

  try {
    const { userAddress, allowanceAtomic, expiryTimestamp } = req.body ?? {};
    if (!userAddress || allowanceAtomic === undefined) {
      return res.status(400).json({ error: 'userAddress and allowanceAtomic required' });
    }
    const expiry = expiryTimestamp == null ? 0n : BigInt(String(expiryTimestamp));

    const { tx1, tx2 } = await runOperatorTxs(async () => {
      const n = await ctx.provider.getTransactionCount(ctx.wallet.address, 'latest');
      const t1 = await ctx.spender.setUserEligibility(userAddress, true, expiry, { nonce: n });
      await t1.wait();
      const t2 = await ctx.spender.setUserAllowance(userAddress, BigInt(String(allowanceAtomic)), { nonce: n + 1 });
      await t2.wait();
      return { tx1: t1, tx2: t2 };
    });

    res.json({ ok: true, eligibilityTxHash: tx1.hash, allowanceTxHash: tx2.hash });
  } catch (e: any) {
    console.error(e);
    res.status(500).json({ error: e.shortMessage ?? e.message ?? String(e) });
  }
});

// POST /api/benefits/deposit
router.post('/deposit', async (req: Request, res: Response) => {
  const ctx = getContracts();
  if (!ctx) return res.status(501).json({ error: 'Benefits contracts not configured' });

  try {
    const { amountAtomic } = req.body ?? {};
    if (amountAtomic === undefined) return res.status(400).json({ error: 'amountAtomic required' });
    const amount = BigInt(String(amountAtomic));

    const tx = await runOperatorTxs(async () => {
      const n = await ctx.provider.getTransactionCount(ctx.wallet.address, 'latest');
      const current = await ctx.usdc.allowance(ctx.wallet.address, ctx.spenderAddr);
      if (BigInt(current.toString()) < amount) {
        const approveTx = await ctx.usdc.approve(ctx.spenderAddr, ethers.MaxUint256, { nonce: n });
        await approveTx.wait();
        const dep = await ctx.spender.depositBenefits(amount, { nonce: n + 1 });
        await dep.wait();
        return dep;
      }
      const dep = await ctx.spender.depositBenefits(amount, { nonce: n });
      await dep.wait();
      return dep;
    });

    res.json({ ok: true, txHash: tx.hash });
  } catch (e: any) {
    console.error(e);
    res.status(500).json({ error: e.shortMessage ?? e.message ?? String(e) });
  }
});

// POST /api/benefits/setup-merchant
router.post('/setup-merchant', async (req: Request, res: Response) => {
  const ctx = getContracts();
  if (!ctx) return res.status(501).json({ error: 'Benefits contracts not configured' });

  try {
    const { merchantAddress, approved } = req.body ?? {};
    if (!merchantAddress || approved === undefined) {
      return res.status(400).json({ error: 'merchantAddress and approved required' });
    }
    const tx = await runOperatorTxs(async () => {
      const t = await ctx.spender.setMerchant(merchantAddress, Boolean(approved));
      await t.wait();
      return t;
    });
    res.json({ ok: true, txHash: tx.hash });
  } catch (e: any) {
    console.error(e);
    res.status(500).json({ error: e.shortMessage ?? e.message ?? String(e) });
  }
});

// POST /api/benefits/pay-merchant
router.post('/pay-merchant', async (req: Request, res: Response) => {
  const ctx = getContracts();
  if (!ctx) return res.status(501).json({ error: 'Benefits contracts not configured' });

  const beneficiaryKey = process.env.BENEFICIARY_PRIVATE_KEY;
  if (!beneficiaryKey) {
    return res.status(501).json({ error: 'BENEFICIARY_PRIVATE_KEY not set' });
  }

  try {
    const { merchantAddress, amountAtomic } = req.body ?? {};
    if (!merchantAddress || amountAtomic === undefined) {
      return res.status(400).json({ error: 'merchantAddress and amountAtomic required' });
    }
    const userWallet  = new ethers.Wallet(beneficiaryKey, ctx.provider);
    const userSpender = ctx.spender.connect(userWallet) as any;
    const tx = await userSpender.payMerchant(merchantAddress, BigInt(String(amountAtomic)));
    await tx.wait();
    res.json({ ok: true, txHash: tx.hash });
  } catch (e: any) {
    console.error(e);
    res.status(500).json({ error: e.shortMessage ?? e.message ?? String(e) });
  }
});

// GET /api/benefits/status/:userAddress
router.get('/status/:userAddress', async (req: Request, res: Response) => {
  const ctx = getContracts();
  if (!ctx) return res.status(501).json({ error: 'Benefits contracts not configured' });

  try {
    const { userAddress } = req.params;
    if (!ethers.isAddress(userAddress)) {
      return res.status(400).json({ error: 'invalid address' });
    }

    const [eligible, allowance, spent, expiry, paused] = await Promise.all([
      ctx.spender.approvedUsers(userAddress),
      ctx.spender.userAllowance(userAddress),
      ctx.spender.userSpent(userAddress),
      ctx.spender.userExpiry(userAddress),
      ctx.spender.paused(),
    ]);

    const allowanceBn = BigInt(allowance.toString());
    const spentBn     = BigInt(spent.toString());
    const remaining   = allowanceBn > spentBn ? allowanceBn - spentBn : 0n;

    res.json({
      userAddress,
      eligible,
      allowanceAtomic:  allowance.toString(),
      spentAtomic:      spent.toString(),
      remainingAtomic:  remaining.toString(),
      expiryTimestamp:  expiry.toString(),
      paused,
    });
  } catch (e: any) {
    console.error(e);
    res.status(500).json({ error: e.shortMessage ?? e.message ?? String(e) });
  }
});

export default router;
