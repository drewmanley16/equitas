export function getArcExplorerBaseURL(): string | null {
  const explicit = process.env.ARC_EXPLORER_BASE_URL?.trim();
  if (explicit) {
    return explicit.replace(/\/+$/, '');
  }

  const chainId = Number(process.env.CHAIN_ID ?? 31337);
  switch (chainId) {
    case 10200:
      return 'https://gnosis-chiado.blockscout.com';
    case 100:
      return 'https://gnosis.blockscout.com';
    default:
      return null;
  }
}

export function buildArcTxURL(txHash: string): string | null {
  const base = getArcExplorerBaseURL();
  if (!base || !txHash) {
    return null;
  }
  return `${base}/tx/${txHash}`;
}
