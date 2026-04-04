export type IncomeAttestationRecord = {
  proofHash: string;
  grossMonthlyCents: number;
  benefitAtomic: string;
  benefitTier: string;
  eligible: boolean;
  createdAt: number;
};

const attestationRecords = new Map<string, IncomeAttestationRecord>();
const RECORD_TTL_MS = 24 * 60 * 60 * 1000;

function cleanupLater(proofHash: string) {
  setTimeout(() => {
    attestationRecords.delete(proofHash);
  }, RECORD_TTL_MS);
}

export function registerIncomeAttestation(record: IncomeAttestationRecord) {
  attestationRecords.set(record.proofHash, record);
  cleanupLater(record.proofHash);
}

export function getIncomeAttestation(proofHash: string): IncomeAttestationRecord | undefined {
  return attestationRecords.get(proofHash);
}

export function deriveBenefitFromIncome(grossMonthly: number): {
  grossMonthlyCents: number;
  benefitAtomic: string;
  benefitTier: string;
} {
  const grossMonthlyCents = Math.round(grossMonthly * 100);

  // Demo-friendly descending tiers. Keeps raw income off-chain while letting
  // Hedera metadata and ARC funding reflect a verified derived benefit amount.
  if (grossMonthlyCents <= 80000) {
    return { grossMonthlyCents, benefitAtomic: '500000000', benefitTier: 'tier_max' }; // 500 USDC
  }
  if (grossMonthlyCents <= 120000) {
    return { grossMonthlyCents, benefitAtomic: '400000000', benefitTier: 'tier_high' }; // 400 USDC
  }
  if (grossMonthlyCents <= 160000) {
    return { grossMonthlyCents, benefitAtomic: '300000000', benefitTier: 'tier_mid' }; // 300 USDC
  }
  return { grossMonthlyCents, benefitAtomic: '200000000', benefitTier: 'tier_entry' }; // 200 USDC
}

export function deriveBenefitTierFromAtomic(benefitAtomic: string): string {
  switch (String(benefitAtomic)) {
    case '500000000':
      return 'tier_max';
    case '400000000':
      return 'tier_high';
    case '300000000':
      return 'tier_mid';
    case '200000000':
      return 'tier_entry';
    default:
      return 'tier_custom';
  }
}
