import { Router, Request, Response } from 'express';

const router = Router();

// POST /api/zk/prove
// Receives hashed income fields, returns a mock ZK proof for now
// TODO: integrate Noir/Circom circuit runner
router.post('/prove', (req: Request, res: Response) => {
  const { grossHash, employerHash, periodStartHash, periodEndHash } = req.body;

  if (!grossHash) {
    return res.status(400).json({ error: 'grossHash required' });
  }

  // Stub proof — replace with real Noir prover output
  const proof = Buffer.from(
    JSON.stringify({ grossHash, employerHash, periodStartHash, periodEndHash, eligible: true })
  ).toString('hex');

  res.json({
    proof,
    publicSignals: [grossHash, '1'],  // [gross_hash, eligibility_result]
  });
});

export default router;
