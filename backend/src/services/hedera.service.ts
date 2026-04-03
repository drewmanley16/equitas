import {
  Client,
  TokenMintTransaction,
  TransferTransaction,
  AccountId,
  PrivateKey,
  TokenId,
  NftId,
  TokenAssociateTransaction,
} from '@hashgraph/sdk';
import { config } from '../config';

function getClient(): Client {
  const client = config.hedera.network === 'mainnet'
    ? Client.forMainnet()
    : Client.forTestnet();

  if (config.hedera.accountID && config.hedera.privateKey) {
    client.setOperator(
      AccountId.fromString(config.hedera.accountID),
      PrivateKey.fromString(config.hedera.privateKey)
    );
  }
  return client;
}

export async function mintEligibilityNFT(params: {
  walletAddress: string;
  proofHash: string;
  worldIDNullifier: string;
}): Promise<{ tokenId: string; serialNumber: number; txId: string }> {
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
