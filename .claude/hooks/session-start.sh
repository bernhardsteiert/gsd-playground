#!/bin/bash
set -euo pipefail

# Only run in remote (web) environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

echo "Installing get-shit-done-cc..."
npx --yes get-shit-done-cc@latest --claude --global
echo "get-shit-done-cc installed successfully."
