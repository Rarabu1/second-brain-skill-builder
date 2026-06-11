#!/usr/bin/env bash
# Safe deploy wrapper for secondbrain.training.
# Runs the pre-deploy guard, then deploys only if it passes.
# Always use this instead of calling `wrangler deploy` directly.
set -euo pipefail

cd "$(dirname "$0")"

./predeploy-check.sh

echo "Deploying..."
exec npx wrangler deploy "$@"
