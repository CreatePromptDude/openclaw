#!/usr/bin/env bash
set -euo pipefail

# Deterministic + cooperative fleet rollout for OpenClaw fork.
# - Builds image from current repo HEAD
# - Stamps prompt DNA version
# - Updates /opt/openclaw-agents.json
# - Drains briefly (cooperative window) before restart
# - Restarts all agents and hard-verifies image + DNA stamp

CONFIG_PATH="${OPENCLAW_AGENTS_CONFIG:-/opt/openclaw-agents.json}"
IMAGE_PREFIX="${OPENCLAW_IMAGE_PREFIX:-createprompt/openclaw}"
REPO_DIR="${1:-$(pwd)}"
DRAIN_SECONDS="${OPENCLAW_DRAIN_SECONDS:-20}"
EXPECTED_AGENTS="${OPENCLAW_EXPECTED_AGENTS:-anchor vex rune spark claw eve}"

cd "$REPO_DIR"

git fetch origin main
git checkout main
git pull --ff-only origin main

SHA="$(git rev-parse --short=12 HEAD)"
IMAGE_TAG="${IMAGE_PREFIX}:${SHA}"
DNA_VERSION="${SHA}"

echo "[deploy] building ${IMAGE_TAG}"
docker build --build-arg OPENCLAW_PROMPT_DNA_VERSION="$DNA_VERSION" -t "$IMAGE_TAG" .

echo "[deploy] patching ${CONFIG_PATH}"
python3 - <<PY
import json
p='${CONFIG_PATH}'
with open(p) as f:
    cfg=json.load(f)
cfg['image']='${IMAGE_TAG}'
shared=cfg.setdefault('shared_env',{})
shared['OPENCLAW_PROMPT_DNA_VERSION']='${DNA_VERSION}'
with open(p,'w') as f:
    json.dump(cfg,f,indent=2); f.write('\n')
print('updated image=',cfg['image'],'dna=',shared['OPENCLAW_PROMPT_DNA_VERSION'])
PY

if ! [[ "$DRAIN_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "Invalid OPENCLAW_DRAIN_SECONDS: $DRAIN_SECONDS" >&2
  exit 1
fi

echo "[deploy] cooperative drain window: ${DRAIN_SECONDS}s"
sleep "$DRAIN_SECONDS"

echo "[deploy] restarting all agents"
ocm restart all

echo "[deploy] verifying running images + DNA"
for c in $EXPECTED_AGENTS; do
  running=$(docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null || true)
  img=$(docker inspect "$c" --format '{{.Config.Image}}' 2>/dev/null || true)
  dna=$(docker inspect "$c" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep '^OPENCLAW_PROMPT_DNA_VERSION=' | head -n1 | cut -d= -f2)

  echo " - $c running=${running:-false} image=${img:-missing} dna=${dna:-missing}"

  [[ "$running" == "true" ]] || { echo "verify failed: $c not running" >&2; exit 1; }
  [[ "$img" == "$IMAGE_TAG" ]] || { echo "verify failed: $c image mismatch" >&2; exit 1; }
  [[ "$dna" == "$DNA_VERSION" ]] || { echo "verify failed: $c dna mismatch" >&2; exit 1; }
done

echo "[deploy] done"