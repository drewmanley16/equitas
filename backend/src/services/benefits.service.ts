import { ethers } from 'ethers';
import { deriveBenefitTierFromAtomic, getIncomeAttestation } from './attestation.service';

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

export function getBenefitsContracts() {
  const rpcUrl = process.env.RPC_URL;
  const operatorKey = process.env.OPERATOR_PRIVATE_KEY;
  const spenderAddr = process.env.SNAP_SPENDER_ADDRESS;
  const usdcAddr = process.env.USDC_ADDRESS;

  if (!rpcUrl || !operatorKey || !spenderAddr || !usdcAddr) {
    return null;
  }

  const chainId = Number(process.env.CHAIN_ID ?? 31337);
  const provider = new ethers.JsonRpcProvider(rpcUrl, chainId);
  const wallet = new ethers.Wallet(operatorKey, provider);
  const spender = new ethers.Contract(spenderAddr, SNAP_SPENDER_ABI, wallet) as any;
  const usdc = new ethers.Contract(usdcAddr, ERC20_ABI, wallet) as any;
  return { provider, wallet, spender, usdc, spenderAddr };
}

let operatorChain = Promise.resolve<any>(undefined);
function runOperatorTxs<T>(fn: () => Promise<T>): Promise<T> {
  const next = operatorChain.then(() => fn());
  operatorChain = next.catch(() => {});
  return next;
}

export async function approveUserEligibility(params: {
  userAddress: string;
  allowanceAtomic: string;
  expiryTimestamp?: string | null;
}) {
  const ctx = getBenefitsContracts();
  if (!ctx) {
    throw new Error('Benefits contracts not configured (set RPC_URL, OPERATOR_PRIVATE_KEY, SNAP_SPENDER_ADDRESS, USDC_ADDRESS)');
  }

  const expiry = params.expiryTimestamp == null ? 0n : BigInt(String(params.expiryTimestamp));

  return runOperatorTxs(async () => {
    const n = await ctx.provider.getTransactionCount(ctx.wallet.address, 'latest');
    const tx1 = await ctx.spender.setUserEligibility(params.userAddress, true, expiry, { nonce: n });
    await tx1.wait();
    const tx2 = await ctx.spender.setUserAllowance(params.userAddress, BigInt(String(params.allowanceAtomic)), { nonce: n + 1 });
    await tx2.wait();
    return { tx1, tx2 };
  });
}

export async function depositBenefits(amountAtomic: string) {
  const ctx = getBenefitsContracts();
  if (!ctx) {
    throw new Error('Benefits contracts not configured');
  }

  const amount = BigInt(String(amountAtomic));
  return runOperatorTxs(async () => {
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
}

export async function issueBenefitsForEligibleUser(params: {
  userAddress: string;
  nftSerial: number;
  proofHash: string;
  allowanceAtomic?: string;
  depositAtomic?: string;
  expiryTimestamp?: string | null;
}) {
  const attestation = getIncomeAttestation(params.proofHash);
  if (attestation && !attestation.eligible) {
    throw new Error('Income attestation is not eligible for benefits.');
  }

  const allowanceAtomic = params.allowanceAtomic ?? attestation?.benefitAtomic;
  const depositAtomic = params.depositAtomic ?? attestation?.benefitAtomic ?? allowanceAtomic;

  if (!allowanceAtomic || !depositAtomic) {
    throw new Error('No verified income attestation found for this proof hash.');
  }

  const approval = await approveUserEligibility({
    userAddress: params.userAddress,
    allowanceAtomic,
    expiryTimestamp: params.expiryTimestamp,
  });
  const deposit = await depositBenefits(depositAtomic);

  return {
    approvalTxHash: approval.tx1.hash,
    allowanceTxHash: approval.tx2.hash,
    depositTxHash: deposit.hash,
    nftSerial: params.nftSerial,
    proofHash: params.proofHash,
    allowanceAtomic,
    benefitTier: attestation?.benefitTier ?? deriveBenefitTierFromAtomic(allowanceAtomic),
  };
}

export async function getBenefitsStatus(userAddress: string) {
  const ctx = getBenefitsContracts();
  if (!ctx) {
    throw new Error('Benefits contracts not configured');
  }

  const [eligible, allowance, spent, expiry, paused] = await Promise.all([
    ctx.spender.approvedUsers(userAddress),
    ctx.spender.userAllowance(userAddress),
    ctx.spender.userSpent(userAddress),
    ctx.spender.userExpiry(userAddress),
    ctx.spender.paused(),
  ]);

  const allowanceBn = BigInt(allowance.toString());
  const spentBn = BigInt(spent.toString());
  const remaining = allowanceBn > spentBn ? allowanceBn - spentBn : 0n;

  return {
    userAddress,
    eligible,
    allowanceAtomic: allowance.toString(),
    spentAtomic: spent.toString(),
    remainingAtomic: remaining.toString(),
    expiryTimestamp: expiry.toString(),
    paused,
  };
}

export async function setMerchantApproval(params: { merchantAddress: string; approved: boolean }) {
  const ctx = getBenefitsContracts();
  if (!ctx) {
    throw new Error('Benefits contracts not configured');
  }

  return runOperatorTxs(async () => {
    const tx = await ctx.spender.setMerchant(params.merchantAddress, params.approved);
    await tx.wait();
    return tx;
  });
}

export async function payMerchantFromBeneficiary(params: { merchantAddress: string; amountAtomic: string }) {
  const ctx = getBenefitsContracts();
  if (!ctx) {
    throw new Error('Benefits contracts not configured');
  }

  const beneficiaryKey = process.env.BENEFICIARY_PRIVATE_KEY;
  if (!beneficiaryKey) {
    throw new Error('BENEFICIARY_PRIVATE_KEY not set');
  }

  const userWallet = new ethers.Wallet(beneficiaryKey, ctx.provider);
  const userSpender = ctx.spender.connect(userWallet) as any;
  const tx = await userSpender.payMerchant(params.merchantAddress, BigInt(String(params.amountAtomic)));
  await tx.wait();
  return tx;
}
