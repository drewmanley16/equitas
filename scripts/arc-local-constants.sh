#!/usr/bin/env bash
# shellcheck disable=SC2034
# Disposable Anvil default accounts — LOCAL ANVIL ONLY. Never use on mainnet or public testnets.

export PATH="${HOME}/.foundry/bin:/opt/homebrew/bin:/usr/local/bin:${PATH}"

export ANVIL_RPC_URL="${ANVIL_RPC_URL:-http://127.0.0.1:8545}"

# Account #0 — deployer / backend operator (admin)
export ANVIL_ACCOUNT_0_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
export ANVIL_ACCOUNT_0_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

# Account #1 — demo SNAP user (calls payMerchant)
export ANVIL_ACCOUNT_1_ADDRESS="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
export ANVIL_ACCOUNT_1_PRIVATE_KEY="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"

# Account #2 — demo merchant
export ANVIL_ACCOUNT_2_ADDRESS="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
export ANVIL_ACCOUNT_2_PRIVATE_KEY="0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"

# MockUSDC (6 decimals): readable demo amounts
export DEMO_MINT_ADMIN_ATOMIC="1000000000"     # 1000 USDC (6 decimals) minted to admin
export DEMO_USER_ALLOWANCE_ATOMIC="500000000"   # 500 USDC cap
export DEMO_DEPOSIT_ATOMIC="50000000"           # 50 USDC into SNAPSpender
export DEMO_PAYMENT_ATOMIC="10000000"           # 10 USDC payment to merchant
