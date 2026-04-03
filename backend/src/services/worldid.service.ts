import { v4 as uuidv4 } from 'uuid';
import { config } from '../config';

// OIDC redirect URI — must be registered in World ID developer portal
const OIDC_REDIRECT_URI = 'equitas://worldid-oidc-callback';

// In-memory session store — replace with Redis for production
const sessions = new Map<string, { status: 'pending' | 'success' | 'failed'; proof?: any }>();

export function createSession(): string {
  const nonce = uuidv4();
  sessions.set(nonce, { status: 'pending' });
  // Auto-expire after 10 minutes
  setTimeout(() => sessions.delete(nonce), 10 * 60 * 1000);
  return nonce;
}

/** Create-or-update a session keyed by a caller-supplied nonce (for OIDC flow). */
export function upsertSession(nonce: string): void {
  if (!sessions.has(nonce)) {
    sessions.set(nonce, { status: 'pending' });
    setTimeout(() => sessions.delete(nonce), 10 * 60 * 1000);
  }
}

export function getSession(nonce: string) {
  return sessions.get(nonce);
}

export function resolveSession(nonce: string, proofData: any) {
  sessions.set(nonce, { status: 'success', proof: proofData });
}

export function failSession(nonce: string) {
  sessions.set(nonce, { status: 'failed' });
}

export async function exchangeOIDCCode(code: string, codeVerifier: string): Promise<{
  nullifier_hash: string;
  merkle_root?: string;
  credential_type?: string;
}> {
  const body = new URLSearchParams({
    grant_type: 'authorization_code',
    code,
    redirect_uri: OIDC_REDIRECT_URI,
    client_id: config.worldID.appID,
    code_verifier: codeVerifier,
  });

  const res = await fetch('https://id.worldcoin.org/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Token exchange failed: ${errText}`);
  }

  const data = await res.json() as any;
  if (!data.id_token) throw new Error('No id_token in OIDC response');

  // Decode JWT payload (base64url, no signature verification needed — trusted issuer)
  const parts = (data.id_token as string).split('.');
  if (parts.length < 2) throw new Error('Malformed id_token');
  const padded = parts[1].replace(/-/g, '+').replace(/_/g, '/');
  const payload = JSON.parse(Buffer.from(padded, 'base64').toString('utf-8'));

  const wldClaims = payload['https://id.worldcoin.org/v1'] ?? {};
  return {
    nullifier_hash: payload.sub as string,
    merkle_root:    wldClaims.merkle_root,
    credential_type: wldClaims.credential_type,
  };
}

export async function verifyProofWithWorldID(params: {
  proof: string;
  merkle_root: string;
  nullifier_hash: string;
  verification_level: string;
  action: string;
  signal: string;
}): Promise<boolean> {
  const url = `https://developer.worldcoin.org/api/v2/verify/${config.worldID.appID}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(params),
  });

  if (!res.ok) {
    const err = await res.text();
    console.error('World ID verify error:', err);
    return false;
  }

  const data = await res.json() as any;
  return data.success === true || data.verified === true || !!data.nullifier_hash;
}
