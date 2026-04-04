# Backend API examples (curl)

Requires `backend/.env` with `RPC_URL`, `OPERATOR_PRIVATE_KEY`, `SNAP_SPENDER_ADDRESS`, `USDC_ADDRESS`, and matching `CHAIN_ID` (e.g. `31337` for Anvil, `10200` for Chiado).

## Post-verification → restricted USDC funding

This endpoint does **not** verify ZK proofs; another service must confirm eligibility first. The body only needs `verification.verified: true` as the handoff signal.

Expected math for the sample payload: `householdSize` 2 → max $535; income $1000 → benefit $235 → `235000000` atomic units (6 decimals).

```bash
curl -X POST http://localhost:3000/api/post-verification/process \
  -H "Content-Type: application/json" \
  -d '{
    "walletAddress": "0x1111111111111111111111111111111111111111",
    "householdSize": 2,
    "monthlyIncome": 1000,
    "verification": {
      "verified": true,
      "source": "zk-proof",
      "proofId": "demo-proof-1"
    }
  }'
```

## Benefit status lookup

```bash
curl -sfS "http://localhost:3000/api/benefits/status/0x1111111111111111111111111111111111111111"
```

Response fields use `allowanceAtomic`, `spentAtomic`, and `remainingAtomic` (USDC base units as strings).
