#!/usr/bin/env bash
set -euo pipefail

# Deterministic fleet rollout for OpenClaw fork.
# Builds image from current repo HEAD, stamps prompt DNA version, updates /opt/openclaw-agents.json, restarts all agents.

CONFIG_PATH="${OPENCLAW_AGENTS_CONFIG:-/opt/openclaw-agents.json}"
IMAGE_PREFIX="${OPENCLAW_IMAGE_PREFIX:-createprompt/openclaw}"
REPO_DIR="${1:-$(pwd)}"

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

echo "[deploy] restarting all agents"
ocm restart all

echo "[deploy] verifying running images"
for c in $(docker ps --format '{{.Names}}'); do
  img=$(docker inspect "$c" --format '{{.Config.Image}}')
  echo " - $c -> $img"
done

echo "[deploy] done"