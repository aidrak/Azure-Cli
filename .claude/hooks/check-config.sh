#!/bin/bash
# Hook: Check that config.yaml is loaded before running operations
# Runs on SessionStart

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

echo "[HOOK] Session started - Azure VDI Deployment Engine"
echo "[HOOK] Working directory: $PROJECT_DIR"

# Check if config.yaml exists
if [[ ! -f "$PROJECT_DIR/config.yaml" ]]; then
    echo "[HOOK] WARNING: config.yaml not found"
    exit 0
fi

# Reminder to load configuration
echo "[HOOK] Remember to load configuration:"
echo "       source core/config-manager.sh && load_config"

exit 0
