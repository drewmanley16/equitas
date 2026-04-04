import { createEligibilityNFTCollection } from '../services/hedera.service';

type Args = {
  name?: string;
  symbol?: string;
  memo?: string;
  maxSupply?: number;
};

function parseArgs(argv: string[]): Args {
  const result: Args = {};

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];

    switch (arg) {
      case '--name':
        result.name = next;
        i += 1;
        break;
      case '--symbol':
        result.symbol = next;
        i += 1;
        break;
      case '--memo':
        result.memo = next;
        i += 1;
        break;
      case '--max-supply':
        result.maxSupply = next ? Number(next) : undefined;
        i += 1;
        break;
      default:
        break;
    }
  }

  return result;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  console.log('Creating Hedera NFT collection on testnet...');

  const result = await createEligibilityNFTCollection({
    name: args.name,
    symbol: args.symbol,
    memo: args.memo,
    maxSupply: args.maxSupply,
  });

  console.log('');
  console.log('Collection created');
  console.log(`Token ID: ${result.tokenId}`);
  console.log(`Transaction ID: ${result.txId}`);
  console.log(`Name: ${result.name}`);
  console.log(`Symbol: ${result.symbol}`);
  console.log(`Max supply: ${result.maxSupply}`);
  console.log('');
  console.log(`Put this in backend/.env: HEDERA_TOKEN_ID=${result.tokenId}`);
}

main().catch((error) => {
  console.error('Hedera collection creation failed:', error.message ?? error);
  process.exitCode = 1;
});
