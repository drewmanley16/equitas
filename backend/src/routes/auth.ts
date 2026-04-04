import { Router, Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';

const router = Router();

// POST /api/auth/verify-apple
// Validates Sign in with Apple identity token (stub — add full JWT verification for prod)
router.post('/verify-apple', (req: Request, res: Response) => {
  const { identityToken } = req.body;
  if (!identityToken) return res.status(400).json({ error: 'identityToken required' });

  // TODO: validate JWT with Apple's public key (apple-signin-auth package)
  const sessionToken = uuidv4();
  res.json({ sessionToken });
});

export default router;
