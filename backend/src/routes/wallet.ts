import { Router, Request, Response } from 'express';

const router = Router();

router.post('/generate-pass', async (req: Request, res: Response) => {
  const { walletAddress, hederaTokenId, serialNumber, allowanceAtomic, benefitTier } = req.body ?? {};

  if (!walletAddress) {
    return res.status(400).json({ error: 'walletAddress is required' });
  }

  const passTypeIdentifier = process.env.APPLE_WALLET_PASS_TYPE_ID ?? '';
  const teamIdentifier = process.env.APPLE_TEAM_ID ?? '';
  const signingConfigured = Boolean(
    process.env.APPLE_WALLET_SIGNER_CERT_BASE64 &&
    process.env.APPLE_WALLET_SIGNER_KEY_BASE64 &&
    process.env.APPLE_WALLET_WWDR_CERT_BASE64 &&
    passTypeIdentifier &&
    teamIdentifier
  );

  if (!signingConfigured) {
    return res.status(501).json({
      error: 'Apple Wallet pass signing is not configured yet. Set APPLE_WALLET_PASS_TYPE_ID, APPLE_TEAM_ID, APPLE_WALLET_SIGNER_CERT_BASE64, APPLE_WALLET_SIGNER_KEY_BASE64, and APPLE_WALLET_WWDR_CERT_BASE64.',
      supported: false,
      walletAddress,
      hederaTokenId: hederaTokenId ?? null,
      serialNumber: serialNumber ?? null,
      allowanceAtomic: allowanceAtomic ?? null,
      benefitTier: benefitTier ?? null,
    });
  }

  return res.json({
    supported: true,
    message: 'Apple Wallet signing is configured, but pass packaging is not implemented in this hackathon build yet.',
    walletAddress,
    hederaTokenId: hederaTokenId ?? null,
    serialNumber: serialNumber ?? null,
    allowanceAtomic: allowanceAtomic ?? null,
    benefitTier: benefitTier ?? null,
    passTypeIdentifier,
    teamIdentifier,
  });
});

export default router;
