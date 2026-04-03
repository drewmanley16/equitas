import { v4 as uuidv4 } from 'uuid';
import { config } from '../config';

// In-memory session store — replace with Redis for production
const sessions = new Map<string, { status: 'pending' | 'success' | 'failed'; proof?: any }>();

export function createSession(): string {
  const nonce = uuidv4();
  sessions.set(nonce, { status: 'pending' });
  // Auto-expire after 10 minutes
  setTimeout(() => sessions.delete(nonce), 10 * 60 * 1000);
  return nonce;
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
