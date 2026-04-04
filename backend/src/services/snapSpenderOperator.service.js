/**
 * Operator wallet + SNAPSpender (restricted USDC) — shared by benefits routes and post-verification.
 */

/**
 * @param {object} deps
 * @param {import("ethers").ethers} deps.ethers
 * @param {import("ethers").JsonRpcProvider} deps.provider
 * @param {import("ethers").Wallet} deps.wallet
 * @param {import("ethers").Contract} deps.spender SNAPSpender
 * @param {import("ethers").Contract} deps.usdc ERC20 USDC
 * @param {string} deps.spenderAddr checksummed address
 */
export function createSnapSpenderOperator(deps) {
  const { ethers, provider, wallet, spender, usdc, spenderAddr } = deps;

  let operatorChain = Promise.resolve();

  function runOperatorTxs(fn) {
    const next = operatorChain.then(() => fn());
    operatorChain = next.catch(() => {});
    return next;
  }

  const opNonce = () => provider.getTransactionCount(wallet.address, "latest");

  /**
   * Sets eligibility + per-user allowance (same as POST /api/benefits/approve-user).
   */
  async function approveUserEligibilityAndAllowance(userAddress, allowanceAtomic, expiryTimestamp) {
    const expiry =
      expiryTimestamp === undefined || expiryTimestamp === null ? 0n : BigInt(String(expiryTimestamp));

    return runOperatorTxs(async () => {
      const n = await opNonce();
      const t1 = await spender.setUserEligibility(userAddress, true, expiry, { nonce: n });
      await t1.wait();
      const t2 = await spender.setUserAllowance(userAddress, BigInt(String(allowanceAtomic)), {
        nonce: n + 1,
      });
      await t2.wait();
      return { eligibilityTx: t1, allowanceTx: t2 };
    });
  }

  /**
   * Pulls USDC from operator into SNAPSpender (same as POST /api/benefits/deposit).
   */
  async function depositProgramFunds(amountAtomic) {
    const amount = BigInt(String(amountAtomic));
    return runOperatorTxs(async () => {
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
  }

  /**
   * Normalized strings for API responses (allowance / spent / remaining).
   */
  async function getUserFundingStatus(userAddress) {
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

    return {
      userAddress,
      eligible,
      allowance: allowance.toString(),
      spent: spent.toString(),
      remaining: remaining.toString(),
      expiryTimestamp: expiry.toString(),
      paused,
    };
  }

  return {
    runOperatorTxs,
    approveUserEligibilityAndAllowance,
    depositProgramFunds,
    getUserFundingStatus,
  };
}
