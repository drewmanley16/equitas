import { Router, Request, Response } from 'express';
import { getIncomeAttestation } from '../services/attestation.service';
import { issueBenefitsForEligibleUser } from '../services/benefits.service';
import { buildArcTxURL, getArcExplorerBaseURL } from '../services/explorer.service';
import { mintEligibilityNFT, readEligibilityNFTAttestation } from '../services/hedera.service';

const router = Router();

// POST /api/blockchain/mint-nft
router.post('/mint-nft', async (req: Request, res: Response) => {
  const { walletAddress, proofHash, worldIDNullifier } = req.body;

  if (!walletAddress || !proofHash || !worldIDNullifier) {
    return res.status(400).json({ error: 'walletAddress, proofHash, and worldIDNullifier are required' });
  }

  try {
    const attestation = getIncomeAttestation(proofHash);
    if (!attestation) {
      return res.status(404).json({ error: 'No verified income attestation found for this proof hash' });
    }

    const result = await mintEligibilityNFT({
      walletAddress,
      proofHash,
      worldIDNullifier,
      benefitAtomic: attestation.benefitAtomic,
      benefitTier: attestation.benefitTier,
    });
    res.json({
      hederaTokenId: result.tokenId,
      serialNumber:  result.serialNumber,
      txId:          result.txId,
      hederaAccountId: result.recipientAccountId,
      createdRecipientAccount: result.createdRecipientAccount,
      allowanceAtomic: attestation.benefitAtomic,
      benefitTier: attestation.benefitTier,
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
    hederaTokenId,
    serialNumber,
    proofHash,
    allowanceAtomic,
    depositAtomic,
    expiryTimestamp,
  } = req.body ?? {};
  if (!walletAddress || serialNumber === undefined) {
    return res.status(400).json({ error: 'walletAddress and serialNumber are required' });
  }

  try {
    let resolvedProofHash = proofHash == null ? null : String(proofHash);
    let resolvedAllowanceAtomic = allowanceAtomic == null ? undefined : String(allowanceAtomic);
    let resolvedDepositAtomic = depositAtomic == null ? undefined : String(depositAtomic);

    if (hederaTokenId) {
      const nftAttestation = await readEligibilityNFTAttestation({
        tokenId: String(hederaTokenId),
        serialNumber: Number(serialNumber),
      });
      resolvedProofHash = nftAttestation.proofHash;
      resolvedAllowanceAtomic ??= nftAttestation.benefitAtomic;
      resolvedDepositAtomic ??= nftAttestation.benefitAtomic;
    }

    if (!resolvedProofHash) {
      return res.status(400).json({ error: 'proofHash or hederaTokenId is required to derive eligibility funding' });
    }

    const result = await issueBenefitsForEligibleUser({
      userAddress: walletAddress,
      nftSerial: Number(serialNumber),
      proofHash: resolvedProofHash,
      allowanceAtomic: resolvedAllowanceAtomic,
      depositAtomic: resolvedDepositAtomic,
      expiryTimestamp: expiryTimestamp == null ? null : String(expiryTimestamp),
    });

    res.json({
      ok: true,
      serialNumber: result.nftSerial,
      proofHash: result.proofHash,
      hederaTokenId: hederaTokenId == null ? null : String(hederaTokenId),
      allowanceAtomic: result.allowanceAtomic,
      benefitTier: result.benefitTier,
      explorerBaseURL: getArcExplorerBaseURL(),
      eligibilityTxHash: result.approvalTxHash,
      allowanceTxHash: result.allowanceTxHash,
      depositTxHash: result.depositTxHash,
      eligibilityExplorerURL: buildArcTxURL(result.approvalTxHash),
      allowanceExplorerURL: buildArcTxURL(result.allowanceTxHash),
      depositExplorerURL: buildArcTxURL(result.depositTxHash),
    });
  } catch (err: any) {
    console.error('ARC issue-tokens error:', err);
    res.status(500).json({ error: err.message });
  }
});

export default router;
