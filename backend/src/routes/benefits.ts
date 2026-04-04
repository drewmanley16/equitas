import { Router, Request, Response } from 'express';
import { ethers } from 'ethers';
import {
  approveUserEligibility,
  depositBenefits,
  getBenefitsContracts,
  getBenefitsStatus,
  payMerchantFromBeneficiary,
  setMerchantApproval,
} from '../services/benefits.service';
import { buildArcTxURL, getArcExplorerBaseURL } from '../services/explorer.service';

const router = Router();

// POST /api/benefits/approve-user
router.post('/approve-user', async (req: Request, res: Response) => {
  const ctx = getBenefitsContracts();
  if (!ctx) return res.status(501).json({ error: 'Benefits contracts not configured (set RPC_URL, OPERATOR_PRIVATE_KEY, SNAP_SPENDER_ADDRESS, USDC_ADDRESS)' });

  try {
    const { userAddress, allowanceAtomic, expiryTimestamp } = req.body ?? {};
    if (!userAddress || allowanceAtomic === undefined) {
      return res.status(400).json({ error: 'userAddress and allowanceAtomic required' });
    }
    const { tx1, tx2 } = await approveUserEligibility({
      userAddress,
      allowanceAtomic: String(allowanceAtomic),
      expiryTimestamp: expiryTimestamp == null ? null : String(expiryTimestamp),
    });

    res.json({
      ok: true,
      eligibilityTxHash: tx1.hash,
      allowanceTxHash: tx2.hash,
      explorerBaseURL: getArcExplorerBaseURL(),
      eligibilityExplorerURL: buildArcTxURL(tx1.hash),
      allowanceExplorerURL: buildArcTxURL(tx2.hash),
    });
  } catch (e: any) {
    console.error(e);
    res.status(500).json({ error: e.shortMessage ?? e.message ?? String(e) });
  }
});

// POST /api/benefits/deposit
router.post('/deposit', async (req: Request, res: Response) => {
  const ctx = getBenefitsContracts();
  if (!ctx) return res.status(501).json({ error: 'Benefits contracts not configured' });

  try {
    const { amountAtomic } = req.body ?? {};
    if (amountAtomic === undefined) return res.status(400).json({ error: 'amountAtomic required' });
    const tx = await depositBenefits(String(amountAtomic));

    res.json({
      ok: true,
      txHash: tx.hash,
      explorerBaseURL: getArcExplorerBaseURL(),
      txExplorerURL: buildArcTxURL(tx.hash),
    });
  } catch (e: any) {
    console.error(e);
    res.status(500).json({ error: e.shortMessage ?? e.message ?? String(e) });
  }
});

// POST /api/benefits/setup-merchant
router.post('/setup-merchant', async (req: Request, res: Response) => {
  const ctx = getBenefitsContracts();
  if (!ctx) return res.status(501).json({ error: 'Benefits contracts not configured' });

  try {
    const { merchantAddress, approved } = req.body ?? {};
    if (!merchantAddress || approved === undefined) {
      return res.status(400).json({ error: 'merchantAddress and approved required' });
    }
    const tx = await setMerchantApproval({ merchantAddress, approved: Boolean(approved) });
    res.json({
      ok: true,
      txHash: tx.hash,
      explorerBaseURL: getArcExplorerBaseURL(),
      txExplorerURL: buildArcTxURL(tx.hash),
    });
  } catch (e: any) {
    console.error(e);
    res.status(500).json({ error: e.shortMessage ?? e.message ?? String(e) });
  }
});

// POST /api/benefits/pay-merchant
router.post('/pay-merchant', async (req: Request, res: Response) => {
  const ctx = getBenefitsContracts();
  if (!ctx) return res.status(501).json({ error: 'Benefits contracts not configured' });

  try {
    const { merchantAddress, amountAtomic } = req.body ?? {};
    if (!merchantAddress || amountAtomic === undefined) {
      return res.status(400).json({ error: 'merchantAddress and amountAtomic required' });
    }
    const tx = await payMerchantFromBeneficiary({
      merchantAddress,
      amountAtomic: String(amountAtomic),
    });
    res.json({
      ok: true,
      txHash: tx.hash,
      explorerBaseURL: getArcExplorerBaseURL(),
      txExplorerURL: buildArcTxURL(tx.hash),
    });
  } catch (e: any) {
    console.error(e);
    res.status(500).json({ error: e.shortMessage ?? e.message ?? String(e) });
  }
});

// GET /api/benefits/status/:userAddress
router.get('/status/:userAddress', async (req: Request, res: Response) => {
  const ctx = getBenefitsContracts();
  if (!ctx) return res.status(501).json({ error: 'Benefits contracts not configured' });

  try {
    const { userAddress } = req.params;
    if (!ethers.isAddress(userAddress)) {
      return res.status(400).json({ error: 'invalid address' });
    }

    res.json(await getBenefitsStatus(userAddress));
  } catch (e: any) {
    console.error(e);
    res.status(500).json({ error: e.shortMessage ?? e.message ?? String(e) });
  }
});

export default router;
