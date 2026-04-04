import { Router, Request, Response } from 'express';
import { config } from '../config';
import {
  createRpContext,
  getLegacySession,
  resolveLegacySession,
  failLegacySession,
  verifyIDKitPayload,
  verifyLegacyProofWithWorldID,
  exchangeOIDCCode,
  upsertLegacySession,
} from '../services/worldid.service';

const router = Router();

// GET /api/worldid/context
// iOS app calls this to get RP context + app config before showing QR
router.post('/context', (req: Request, res: Response) => {
  const signal = req.body?.signal || '';

  try {
    const rpContext = createRpContext();

    res.json({
      ...rpContext,
      app_id: config.worldID.appID,
      action: config.worldID.action,
      signal,
      environment: config.worldID.environment,
    });
  } catch (err: any) {
    res.status(503).json({ error: err.message });
  }
});

// POST /api/worldid/status
// iOS app polls this while waiting for the World App scan
router.post('/status', (req: Request, res: Response) => {
  const { nonce } = req.body;
  if (!nonce) return res.status(400).json({ error: 'nonce required' });

  const session = getLegacySession(nonce);
  if (!session) return res.status(404).json({ error: 'session not found' });

  if (session.status === 'success' && session.proof) {
    return res.json({ status: 'success', ...session.proof });
  }

  res.json({ status: session.status });
});

// POST /api/worldid/verify
// iOS app sends the IDKit result or legacy proof after verification — backend verifies with World ID API
router.post('/verify', async (req: Request, res: Response) => {
  const isStaging = config.worldID.environment === 'staging';

  // v4 IDKit payload (has protocol_version + responses array)
  if (req.body?.protocol_version && Array.isArray(req.body?.responses)) {
    if (isStaging) {
      console.log('World ID staging: accepting v4 proof without API verification');
      return res.json({ success: true, verified: true });
    }
    try {
      const verified = await verifyIDKitPayload(req.body);
      return res.json({ success: verified.success, verified: verified.success });
    } catch (err: any) {
      console.error('World ID v4 verify error:', err.message);
      return res.status(400).json({ error: err.message });
    }
  }

  // Legacy v3 proof fields
  const { proof, merkle_root, nullifier_hash, verification_level, nonce, signal } = req.body;

  if (!proof || !merkle_root || !nullifier_hash) {
    return res.status(400).json({ error: 'Missing proof fields' });
  }

  if (isStaging) {
    console.log('World ID staging: accepting legacy proof without API verification');
    if (nonce) {
      resolveLegacySession(nonce, { proof, merkle_root, nullifier_hash, verification_level });
    }
    return res.json({ success: true, verified: true });
  }

  try {
    const verified = await verifyLegacyProofWithWorldID({
      proof,
      merkle_root,
      nullifier_hash,
      verification_level: verification_level || 'orb',
      action: config.worldID.action,
      signal: signal || '',
    });

    if (verified && nonce) {
      resolveLegacySession(nonce, { proof, merkle_root, nullifier_hash, verification_level });
    }

    res.json({ success: verified, verified });
  } catch (err: any) {
    console.error('World ID verify error:', err);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/worldid/oidc-exchange
// iOS app sends OIDC authorization code + PKCE verifier after redirect callback
// Backend exchanges code for id_token, extracts nullifier_hash
router.post('/oidc-exchange', async (req: Request, res: Response) => {
  const { code, state: nonce, code_verifier } = req.body;

  if (!code || !nonce || !code_verifier) {
    return res.status(400).json({ error: 'code, state, and code_verifier are required' });
  }

  try {
    const result = await exchangeOIDCCode(code, code_verifier);
    upsertLegacySession(nonce);
    resolveLegacySession(nonce, {
      proof:              'oidc',
      merkle_root:        result.merkle_root    ?? '',
      nullifier_hash:     result.nullifier_hash,
      verification_level: result.credential_type ?? 'orb',
    });
    res.json({ success: true, verified: true, nullifier_hash: result.nullifier_hash });
  } catch (err: any) {
    console.error('OIDC exchange error:', err.message);
    failLegacySession(nonce);
    res.status(400).json({ error: err.message });
  }
});

export default router;
