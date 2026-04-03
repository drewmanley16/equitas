import { Router, Request, Response } from 'express';
import { config } from '../config';
import {
  createSession,
  getSession,
  resolveSession,
  verifyProofWithWorldID,
} from '../services/worldid.service';

const router = Router();

// GET /api/worldid/context
// iOS app calls this to get a nonce + app config before showing QR
router.post('/context', (req: Request, res: Response) => {
  const signal = req.body?.signal || '';
  const nonce  = createSession();

  res.json({
    nonce,
    app_id:  config.worldID.appID,
    action:  config.worldID.action,
    signal,
  });
});

// POST /api/worldid/status
// iOS app polls this while waiting for the World App scan
router.post('/status', (req: Request, res: Response) => {
  const { nonce } = req.body;
  if (!nonce) return res.status(400).json({ error: 'nonce required' });

  const session = getSession(nonce);
  if (!session) return res.status(404).json({ error: 'session not found' });

  if (session.status === 'success' && session.proof) {
    return res.json({ status: 'success', ...session.proof });
  }

  res.json({ status: session.status });
});

// POST /api/worldid/verify
// iOS app sends the proof after World App callback — we verify with World ID API
router.post('/verify', async (req: Request, res: Response) => {
  const { proof, merkle_root, nullifier_hash, verification_level, nonce, signal } = req.body;

  if (!proof || !merkle_root || !nullifier_hash) {
    return res.status(400).json({ error: 'Missing proof fields' });
  }

  try {
    const verified = await verifyProofWithWorldID({
      proof,
      merkle_root,
      nullifier_hash,
      verification_level: verification_level || 'orb',
      action: config.worldID.action,
      signal: signal || '',
    });

    if (verified && nonce) {
      resolveSession(nonce, { proof, merkle_root, nullifier_hash, verification_level });
    }

    res.json({ success: verified, verified });
  } catch (err: any) {
    console.error('World ID verify error:', err);
    res.status(500).json({ error: err.message });
  }
});

export default router;
