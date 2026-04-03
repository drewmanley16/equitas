import { signRequest } from '@worldcoin/idkit-core/signing';
import { config } from '../config';

const legacySessions = new Map<string, { status: 'pending' | 'success' | 'failed'; proof?: any }>();
const OIDC_REDIRECT_URI = 'equitas://worldid-oidc-callback';

export function createRpContext() {
  if (!config.worldID.rpID || !config.worldID.rpSigningKey) {
    throw new Error('WORLDID_RP_ID and WORLDID_RP_SIGNING_KEY must be configured.');
  }

  const signature = signRequest(
    {
      action: config.worldID.action,
      signingKeyHex: config.worldID.rpSigningKey,
    }
  );

  return {
    rp_id: config.worldID.rpID,
    nonce: signature.nonce,
    created_at: signature.createdAt,
    expires_at: signature.expiresAt,
    signature: signature.sig,
  };
}

export function createLegacySession(): string {
  const nonce = crypto.randomUUID();
  legacySessions.set(nonce, { status: 'pending' });
  setTimeout(() => legacySessions.delete(nonce), 10 * 60 * 1000);
  return nonce;
}

export function getLegacySession(nonce: string) {
  return legacySessions.get(nonce);
}

export function upsertLegacySession(nonce: string): void {
  if (!legacySessions.has(nonce)) {
    legacySessions.set(nonce, { status: 'pending' });
    setTimeout(() => legacySessions.delete(nonce), 10 * 60 * 1000);
  }
}

export function resolveLegacySession(nonce: string, proofData: any) {
  legacySessions.set(nonce, { status: 'success', proof: proofData });
}

export function failLegacySession(nonce: string) {
  legacySessions.set(nonce, { status: 'failed' });
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

  const parts = (data.id_token as string).split('.');
  if (parts.length < 2) throw new Error('Malformed id_token');
  const padded = parts[1].replace(/-/g, '+').replace(/_/g, '/');
  const payload = JSON.parse(Buffer.from(padded, 'base64').toString('utf-8'));

  const wldClaims = payload['https://id.worldcoin.org/v1'] ?? {};
  return {
    nullifier_hash: payload.sub as string,
    merkle_root: wldClaims.merkle_root,
    credential_type: wldClaims.credential_type,
  };
}

export async function verifyIDKitPayload(payload: unknown) {
  if (!config.worldID.rpID) {
    throw new Error('WORLDID_RP_ID must be configured.');
  }

  const url = `https://developer.world.org/api/v4/verify/${config.worldID.rpID}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    throw new Error(await res.text());
  }

  return res.json() as Promise<{
    success: boolean;
    nullifier?: string;
    session_id?: string;
    message?: string;
  }>;
}

export async function verifyLegacyProofWithWorldID(params: {
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
    console.error('World ID legacy verify error:', err);
    return false;
  }

  const data = await res.json() as any;
  return data.success === true || data.verified === true || !!data.nullifier_hash;
}
