import dotenv from 'dotenv';
dotenv.config();

export const config = {
  port: process.env.PORT || 3000,

  // World ID
  worldID: {
    appID:        process.env.WORLDID_APP_ID         || 'app_6dc3841d23546ffd0ded96c75161a346',
    action:       process.env.WORLDID_ACTION         || 'equitas01',
    rpID:         process.env.WORLDID_RP_ID          || '',
    rpSigningKey: process.env.WORLDID_RP_SIGNING_KEY || '',
    environment:  process.env.WORLDID_ENVIRONMENT    || 'staging',
  },

  // Hedera
  hedera: {
    accountID:  process.env.HEDERA_ACCOUNT_ID  || '',
    privateKey: process.env.HEDERA_PRIVATE_KEY || '',
    tokenID:    process.env.HEDERA_TOKEN_ID    || '',   // pre-created NFT token class
    network:    (process.env.HEDERA_NETWORK    || 'testnet') as 'testnet' | 'mainnet',
  },

  // Gnosis Chain / ARC
  gnosis: {
    rpcURL:              process.env.GNOSIS_RPC_URL        || 'https://rpc.chiadochain.net',
    snapTokenAddress:    process.env.SNAP_TOKEN_ADDRESS    || '',
    minterPrivateKey:    process.env.MINTER_PRIVATE_KEY    || '',
  },

  // Apple Sign In
  apple: {
    clientID: process.env.APPLE_CLIENT_ID || 'com.anonymous.SNAP.verify.equitas',
    teamID:   process.env.APPLE_TEAM_ID   || 'X9H68STU8F',
  },
};
