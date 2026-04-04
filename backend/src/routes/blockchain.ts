import { Router, Request, Response } from 'express';
import { issueBenefitsForEligibleUser } from '../services/benefits.service';
import { mintEligibilityNFT } from '../services/hedera.service';

const router = Router();

const DEFAULT_ALLOWANCE_ATOMIC = '1000000000';
const DEFAULT_DEPOSIT_ATOMIC = '100000000';

// POST /api/blockchain/mint-nft
router.post('/mint-nft', async (req: Request, res: Response) => {
  const { walletAddress, proofHash, worldIDNullifier } = req.body;

  if (!walletAddress || !proofHash || !worldIDNullifier) {
    return res.status(400).json({ error: 'walletAddress, proofHash, and worldIDNullifier are required' });
  }

  try {
    const result = await mintEligibilityNFT({
      walletAddress,
      proofHash,
      worldIDNullifier,
    });
    res.json({
      hederaTokenId: result.tokenId,
      serialNumber:  result.serialNumber,
      txId:          result.txId,
      hederaAccountId: result.recipientAccountId,
      createdRecipientAccount: result.createdRecipientAccount,
    });
  } catch (err: any) {
    console.error('Hedera mint error:', err);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/blockchain/issue-tokens
router.post('/issue-tokens', async (req: Request, res: Response) => {
  const {
    walletAddress,
    serialNumber,
    proofHash,
    allowanceAtomic = DEFAULT_ALLOWANCE_ATOMIC,
    depositAtomic = DEFAULT_DEPOSIT_ATOMIC,
    expiryTimestamp,
  } = req.body ?? {};
  if (!walletAddress || serialNumber === undefined || !proofHash) {
    return res.status(400).json({ error: 'walletAddress, serialNumber, and proofHash are required' });
  }

  try {
    const result = await issueBenefitsForEligibleUser({
      userAddress: walletAddress,
      nftSerial: Number(serialNumber),
      proofHash,
      allowanceAtomic: String(allowanceAtomic),
      depositAtomic: String(depositAtomic),
      expiryTimestamp: expiryTimestamp == null ? null : String(expiryTimestamp),
    });

    res.json({
      ok: true,
      serialNumber: result.nftSerial,
      proofHash: result.proofHash,
      eligibilityTxHash: result.approvalTxHash,
      allowanceTxHash: result.allowanceTxHash,
      depositTxHash: result.depositTxHash,
    });
  } catch (err: any) {
    console.error('ARC issue-tokens error:', err);
    res.status(500).json({ error: err.message });
  }
});

export default router;
