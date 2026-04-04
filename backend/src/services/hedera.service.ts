import {
  Client,
  Hbar,
  AccountCreateTransaction,
  TokenAssociateTransaction,
  TokenCreateTransaction,
  TokenType,
  TokenSupplyType,
  TokenInfoQuery,
  TokenMintTransaction,
  TransferTransaction,
  TokenGrantKycTransaction,
  AccountId,
  PrivateKey,
  TokenId,
  NftId,
} from '@hashgraph/sdk';
import { config } from '../config';

type HederaRecipientAccount = {
  walletAddress: string;
  accountId: string;
  privateKey: string;
};

const demoRecipientAccounts = new Map<string, HederaRecipientAccount>();

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

function normalizeWalletAddress(value: string): string {
  return value.trim().toLowerCase();
}

async function ensureRecipientAccount(walletAddress: string): Promise<{ account: HederaRecipientAccount; created: boolean }> {
  const normalizedWallet = normalizeWalletAddress(walletAddress);
  const existing = demoRecipientAccounts.get(normalizedWallet);
  if (existing) {
    return { account: existing, created: false };
  }

  const client = getClient();
  try {
    const recipientKey = PrivateKey.generateECDSA();
    const tx = await new AccountCreateTransaction()
      .setKey(recipientKey.publicKey)
      .setInitialBalance(new Hbar(5))
      .setMaxAutomaticTokenAssociations(10)
      .execute(client);

    const receipt = await tx.getReceipt(client);
    const accountId = receipt.accountId?.toString();
    if (!accountId) {
      throw new Error('Hedera did not return a recipient account ID.');
    }

    const account = {
      walletAddress: normalizedWallet,
      accountId,
      privateKey: recipientKey.toStringDer(),
    };
    demoRecipientAccounts.set(normalizedWallet, account);
    return { account, created: true };
  } finally {
    client.close();
  }
}

async function grantKycAndTransferNFT(params: {
  tokenId: string;
  serialNumber: number;
  recipientAccount: HederaRecipientAccount;
}) {
  const client = getClient();
  const recipientClient = config.hedera.network === 'mainnet'
    ? Client.forMainnet()
    : Client.forTestnet();
  try {
    recipientClient.setOperator(
      AccountId.fromString(params.recipientAccount.accountId),
      parseHederaPrivateKey(params.recipientAccount.privateKey)
    );

    await new TokenAssociateTransaction()
      .setAccountId(AccountId.fromString(params.recipientAccount.accountId))
      .setTokenIds([TokenId.fromString(params.tokenId)])
      .execute(recipientClient)
      .then((tx) => tx.getReceipt(recipientClient));

    await new TokenGrantKycTransaction()
      .setTokenId(TokenId.fromString(params.tokenId))
      .setAccountId(AccountId.fromString(params.recipientAccount.accountId))
      .execute(client)
      .then((tx) => tx.getReceipt(client));

    const transferTx = await new TransferTransaction()
      .addNftTransfer(
        new NftId(TokenId.fromString(params.tokenId), params.serialNumber),
        AccountId.fromString(config.hedera.accountID),
        AccountId.fromString(params.recipientAccount.accountId)
      )
      .execute(client);

    await transferTx.getReceipt(client);
  } finally {
    recipientClient.close();
    client.close();
  }
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
}): Promise<{ tokenId: string; serialNumber: number; txId: string; recipientAccountId: string; createdRecipientAccount: boolean }> {
  if (!config.hedera.tokenID) {
    throw new Error('Hedera testnet minting is not configured. Set HEDERA_TOKEN_ID, HEDERA_ACCOUNT_ID, and HEDERA_PRIVATE_KEY.');
  }
  requireHederaOperator();
  const { account: recipientAccount, created } = await ensureRecipientAccount(params.walletAddress);

  const client = getClient();

  const compactMetadata = JSON.stringify({
    p: params.proofHash,
    n: params.worldIDNullifier,
  });
  const metadata = Buffer.from(compactMetadata, 'utf8');

  if (metadata.length > 100) {
    throw new Error(`Hedera NFT metadata too large (${metadata.length} bytes). Use shorter proof/nullifier values.`);
  }

  // Mint the NFT
  const mintTx = await new TokenMintTransaction()
    .setTokenId(config.hedera.tokenID)
    .addMetadata(metadata)
    .execute(client);

  const receipt = await mintTx.getReceipt(client);
  const serialNumber = receipt.serials[0].toNumber();
  const tokenId = config.hedera.tokenID;

  try {
    await grantKycAndTransferNFT({
      tokenId,
      serialNumber,
      recipientAccount,
    });
    console.log(`NFT transferred to Hedera account ${recipientAccount.accountId}`);
  } catch (err) {
    console.warn('NFT transfer skipped:', err);
  }

  client.close();

  return {
    tokenId,
    serialNumber,
    txId: mintTx.transactionId.toString(),
    recipientAccountId: recipientAccount.accountId,
    createdRecipientAccount: created,
  };
}
