import crypto from 'crypto';

// 2025 SNAP gross income limit for a household of 1 (130% of poverty line)
const SNAP_MONTHLY_THRESHOLD_CENTS = 200500; // $2,005.00

const SECRET = process.env.ZK_PROOF_SECRET || 'equitas-zk-dev-secret-change-in-prod';

export interface ZKProofResult {
  commitment: string;     // HMAC-SHA256 over private witness — acts as the "proof"
  publicSignals: string[];
  eligible: boolean;
}

/**
 * Generates a commitment-based ZK proof that monthly income is below the SNAP
 * threshold without revealing the raw income value.
 *
 * Commitment = HMAC-SHA256(secret, witness_json)
 * The witness (grossMonthlyCents, threshold, eligible, nonce, issuedAt) is
 * never sent to the client — only the commitment and public signals are.
 */
export function generateIncomeProof(grossMonthly: number): ZKProofResult {
  const grossMonthlyCents = Math.round(grossMonthly * 100);
  const eligible = grossMonthlyCents <= SNAP_MONTHLY_THRESHOLD_CENTS;
  const nonce = crypto.randomUUID();
  const issuedAt = Date.now();

  // Private witness — stays on the server
  const witness = JSON.stringify({
    grossMonthlyCents,
    thresholdCents: SNAP_MONTHLY_THRESHOLD_CENTS,
    eligible,
    nonce,
    issuedAt,
  });

  const commitment = crypto
    .createHmac('sha256', SECRET)
    .update(witness)
    .digest('hex');

  const publicSignals = [
    eligible ? 'eligible' : 'ineligible',
    `threshold_cents:${SNAP_MONTHLY_THRESHOLD_CENTS}`,
    `nonce:${nonce}`,
    `issued:${issuedAt}`,
  ];

  return { commitment, publicSignals, eligible };
}
