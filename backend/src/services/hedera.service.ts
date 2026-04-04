import {
  Client,
  Hbar,
  TokenCreateTransaction,
  TokenType,
  TokenSupplyType,
  TokenInfoQuery,
  TokenMintTransaction,
  TransferTransaction,
  AccountId,
  PrivateKey,
  TokenId,
  NftId,
} from '@hashgraph/sdk';
import { config } from '../config';

function parseHederaPrivateKey(value: string): PrivateKey {
  const normalized = value.trim().replace(/^0x/i, '');

  const parsers = [
    () => PrivateKey.fromStringED25519(normalized),
    () => PrivateKey.fromStringECDSA(normalized),
    () => PrivateKey.fromStringDer(normalized),
    () => PrivateKey.fromString(value.trim()),
  ];

  for (const parse of parsers) {
    try {
      return parse();
    } catch {
      continue;
    }
  }

  throw new Error('Could not parse HEDERA_PRIVATE_KEY. Use the Portal private key value for the selected Hedera account.');
}

function getClient(): Client {
  const client = config.hedera.network === 'mainnet'
    ? Client.forMainnet()
    : Client.forTestnet();

  if (config.hedera.accountID && config.hedera.privateKey) {
    client.setOperator(
      AccountId.fromString(config.hedera.accountID),
      parseHederaPrivateKey(config.hedera.privateKey)
    );
  }
  return client;
}

function requireHederaOperator(): { accountId: string; privateKey: string } {
  if (!config.hedera.accountID || !config.hedera.privateKey) {
    throw new Error('Hedera operator is not configured. Set HEDERA_ACCOUNT_ID and HEDERA_PRIVATE_KEY.');
  }

  return {
    accountId: config.hedera.accountID,
    privateKey: config.hedera.privateKey,
  };
}

export async function createEligibilityNFTCollection(params?: {
  name?: string;
  symbol?: string;
  memo?: string;
  maxSupply?: number;
}): Promise<{ tokenId: string; txId: string; name: string; symbol: string; maxSupply: number }> {
  const { accountId } = requireHederaOperator();
  const client = getClient();
  const operatorKey = parseHederaPrivateKey(config.hedera.privateKey);

  const name = params?.name || 'Equitas SNAP Eligibility';
  const symbol = params?.symbol || 'EQUITAS';
  const memo = params?.memo || 'Equitas eligibility attestation NFT';
  const maxSupply = params?.maxSupply ?? 100000;

  try {
    const tx = await new TokenCreateTransaction()
      .setTokenName(name)
      .setTokenSymbol(symbol)
      .setTokenMemo(memo)
      .setTokenType(TokenType.NonFungibleUnique)
      .setSupplyType(TokenSupplyType.Finite)
      .setMaxSupply(maxSupply)
      .setInitialSupply(0)
      .setTreasuryAccountId(AccountId.fromString(accountId))
      .setSupplyKey(operatorKey)
      .setAdminKey(operatorKey)
      .setPauseKey(operatorKey)
      .setFreezeKey(operatorKey)
      .setKycKey(operatorKey)
      .setMaxTransactionFee(new Hbar(30))
      .execute(client);

    const receipt = await tx.getReceipt(client);
    const tokenId = receipt.tokenId?.toString();
    if (!tokenId) {
      throw new Error('Hedera did not return a token ID.');
    }

    await new TokenInfoQuery()
      .setTokenId(TokenId.fromString(tokenId))
      .execute(client);

    return {
      tokenId,
      txId: tx.transactionId.toString(),
      name,
      symbol,
      maxSupply,
    };
  } finally {
    client.close();
  }
}

export async function mintEligibilityNFT(params: {
  walletAddress: string;
  proofHash: string;
  worldIDNullifier: string;
}): Promise<{ tokenId: string; serialNumber: number; txId: string }> {
  if (!config.hedera.tokenID) {
    throw new Error('Hedera testnet minting is not configured. Set HEDERA_TOKEN_ID, HEDERA_ACCOUNT_ID, and HEDERA_PRIVATE_KEY.');
  }
  requireHederaOperator();

  const client = getClient();

  const metadata = Buffer.from(JSON.stringify({
    name: 'SNAP Eligibility — Equitas',
    walletAddress: params.walletAddress,
    proofHash: params.proofHash,
    worldIDNullifier: params.worldIDNullifier,
    issuedAt: new Date().toISOString(),
  }));

  // Mint the NFT
  const mintTx = await new TokenMintTransaction()
    .setTokenId(config.hedera.tokenID)
    .addMetadata(metadata)
    .execute(client);

  const receipt = await mintTx.getReceipt(client);
  const serialNumber = receipt.serials[0].toNumber();
  const tokenId = config.hedera.tokenID;

  // Associate + transfer to user's EVM-compatible Hedera account
  // Note: walletAddress is an EVM address — convert to Hedera account format
  try {
    const transferTx = await new TransferTransaction()
      .addNftTransfer(
        new NftId(TokenId.fromString(tokenId), serialNumber),
        AccountId.fromString(config.hedera.accountID),
        AccountId.fromEvmAddress(0, 0, params.walletAddress)
      )
      .execute(client);

    const transferReceipt = await transferTx.getReceipt(client);
    console.log('NFT transferred:', transferReceipt.status.toString());
  } catch (err) {
    // Transfer may fail if account not yet on Hedera — NFT stays with operator for now
    console.warn('NFT transfer skipped (account not yet on Hedera):', err);
  }

  client.close();

  return {
    tokenId,
    serialNumber,
    txId: mintTx.transactionId.toString(),
  };
}
