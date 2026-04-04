import { mintEligibilityNFT } from '../services/hedera.service';

type Args = {
  walletAddress?: string;
  proofHash?: string;
  worldIDNullifier?: string;
};

function parseArgs(argv: string[]): Args {
  const result: Args = {};

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];

    switch (arg) {
      case '--wallet':
        result.walletAddress = next;
        i += 1;
        break;
      case '--proof':
        result.proofHash = next;
        i += 1;
        break;
      case '--nullifier':
        result.worldIDNullifier = next;
        i += 1;
        break;
      default:
        break;
    }
  }

  return result;
}

function requiredValue(value: string | undefined, name: string): string {
  if (!value || !value.trim()) {
    throw new Error(`Missing ${name}. Pass it as a flag or set the matching environment variable.`);
  }
  return value.trim();
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  const walletAddress = requiredValue(
    args.walletAddress ?? process.env.MINT_WALLET_ADDRESS,
    'wallet address (--wallet / MINT_WALLET_ADDRESS)'
  );
  const proofHash = requiredValue(
    args.proofHash ?? process.env.MINT_PROOF_HASH,
    'proof hash (--proof / MINT_PROOF_HASH)'
  );
  const worldIDNullifier = requiredValue(
    args.worldIDNullifier ?? process.env.MINT_WORLD_ID_NULLIFIER,
    'World ID nullifier (--nullifier / MINT_WORLD_ID_NULLIFIER)'
  );

  console.log('Minting Hedera eligibility NFT on testnet...');
  console.log(`Wallet: ${walletAddress}`);
  console.log(`Proof hash: ${proofHash}`);
  console.log(`World ID nullifier: ${worldIDNullifier}`);

  const result = await mintEligibilityNFT({
    walletAddress,
    proofHash,
    worldIDNullifier,
    benefitAtomic: process.env.MINT_BENEFIT_ATOMIC || '300000000',
    benefitTier: process.env.MINT_BENEFIT_TIER || 'tier_mid',
  });

  console.log('');
  console.log('Mint complete');
  console.log(`Token ID: ${result.tokenId}`);
  console.log(`Serial: ${result.serialNumber}`);
  console.log(`Transaction ID: ${result.txId}`);
}

main().catch((error) => {
  console.error('Hedera mint failed:', error.message ?? error);
  process.exitCode = 1;
});
