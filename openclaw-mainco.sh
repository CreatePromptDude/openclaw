#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  set -a
  source "$SCRIPT_DIR/.env"
  set +a
fi

unset OPENCLAW_GATEWAY_TOKEN
unset OPENCLAW_GATEWAY_PASSWORD
unset OPENCLAW_GATEWAY_URL
unset PI_CODING_AGENT_DIR
unset CLAWDBOT_STATE_DIR
unset CLAWDBOT_CONFIG_PATH
unset CLAWDBOT_GATEWAY_PORT

# Dedicated profile ensures a unique service label on macOS launchd.
export OPENCLAW_PROFILE="${OPENCLAW_PROFILE:-mainco}"

# Keep this company's existing config/state roots.
export OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME}"
export OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"
export OPENCLAW_CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-$HOME/.openclaw/openclaw.json}"
export OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"

mkdir -p "$OPENCLAW_STATE_DIR"

cd "$SCRIPT_DIR"
if [[ -f "$SCRIPT_DIR/dist/index.js" ]]; then
  exec node dist/index.js "$@"
fi
exec node scripts/run-node.mjs "$@"
