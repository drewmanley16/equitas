import { Router, Request, Response } from 'express';
import { mintEligibilityNFT } from '../services/hedera.service';

const router = Router();

// POST /api/blockchain/mint-nft
router.post('/mint-nft', async (req: Request, res: Response) => {
  const { walletAddress, proofHash, worldIDNullifier } = req.body;

  if (!walletAddress) {
    return res.status(400).json({ error: 'walletAddress required' });
  }

  try {
    const result = await mintEligibilityNFT({
      walletAddress,
      proofHash:        proofHash        || 'demo',
      worldIDNullifier: worldIDNullifier || 'demo',
    });
    res.json({
      hederaTokenId: result.tokenId,
      serialNumber:  result.serialNumber,
      txId:          result.txId,
    });
  } catch (err: any) {
    console.error('Hedera mint error:', err);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/blockchain/issue-tokens
// Placeholder — SNAPtoken issuance on ARC/Gnosis Chain
router.post('/issue-tokens', async (req: Request, res: Response) => {
  const { walletAddress, serialNumber } = req.body;
  if (!walletAddress) return res.status(400).json({ error: 'walletAddress required' });

  // TODO: call ERC-20 mint on Gnosis Chiado testnet via ethers.js
  console.log(`Issuing SNAPtokens to ${walletAddress} (NFT serial #${serialNumber})`);
  res.json({ txHash: '0xdemo', amount: '847.50' });
});

export default router;
