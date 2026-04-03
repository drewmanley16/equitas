#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
forge install foundry-rs/forge-std OpenZeppelin/openzeppelin-contracts
