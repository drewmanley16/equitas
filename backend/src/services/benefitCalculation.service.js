/**
 * Pure SNAP-style max benefit + net benefit calculation (off-chain policy).
 * USDC amounts use 6 decimals; base units are stringified integers.
 */

const USDC_DECIMALS = 6;
const USDC_MULTIPLIER = 10n ** BigInt(USDC_DECIMALS);

const MAX_BY_HOUSEHOLD = new Map([
  [1, 291],
  [2, 535],
  [3, 766],
  [4, 973],
  [5, 1155],
  [6, 1386],
]);

/**
 * @param {number} householdSize integer >= 1
 * @returns {number}
 */
export function getMaxBenefit(householdSize) {
  const h = Math.floor(Number(householdSize));
  if (h < 1) {
    throw new Error("householdSize must be >= 1");
  }
  if (h <= 6) {
    return MAX_BY_HOUSEHOLD.get(h) ?? 0;
  }
  return 1386 + (h - 6) * 220;
}

/**
 * @param {string|number|bigint} benefitDollarsInteger non-negative integer dollars
 * @returns {string} USDC base units (6 decimals)
 */
export function dollarsToUsdcBaseUnits(benefitDollarsInteger) {
  const n = BigInt(String(benefitDollarsInteger));
  if (n < 0n) {
    throw new Error("benefit dollars must be non-negative");
  }
  return (n * USDC_MULTIPLIER).toString();
}

/**
 * @param {number} monthlyIncome dollars (may be fractional; clamped at 0)
 * @param {number} householdSize integer >= 1
 * @returns {{
 *   eligible: boolean,
 *   householdSize: number,
 *   monthlyIncome: number,
 *   maxBenefitDollars: number,
 *   benefitDollars: number,
 *   benefitUsdcBaseUnits: string
 * }}
 */
export function calculateBenefit(monthlyIncome, householdSize) {
  const h = Math.floor(Number(householdSize));
  if (!Number.isFinite(h) || h < 1) {
    throw new Error("householdSize must be an integer >= 1");
  }

  const maxBenefit = getMaxBenefit(h);
  const effectiveIncome = Math.max(Number(monthlyIncome), 0);

  let benefit = maxBenefit - 0.3 * effectiveIncome;
  benefit = Math.max(0, benefit);
  benefit = Math.min(benefit, maxBenefit);

  const benefitDollars = Math.floor(benefit);
  const eligible = benefitDollars > 0;

  return {
    eligible,
    householdSize: h,
    monthlyIncome: Number(monthlyIncome),
    maxBenefitDollars: maxBenefit,
    benefitDollars,
    benefitUsdcBaseUnits: dollarsToUsdcBaseUnits(benefitDollars),
  };
}
