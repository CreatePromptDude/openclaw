# Fork Fleet Deploy (Force Latest OpenClaw Fork Image)

Goal: ensure every agent container runs the latest code from your OpenClaw fork, not stale/upstream image bytes.

## One-command flow (on VPS host)

```bash
cd ~/prompt/createprompt
git fetch origin main
git checkout main
git pull --ff-only origin main

SHA=$(git rev-parse --short=12 HEAD)
IMAGE="createprompt/openclaw:${SHA}"

docker build -t "$IMAGE" .

python3 - <<PY
import json
p='/opt/openclaw-agents.json'
with open(p) as f: c=json.load(f)
c['image'] = '${IMAGE}'
with open(p,'w') as f:
    json.dump(c,f,indent=2); f.write('\n')
print('updated', p, 'image=', c['image'])
PY

ocm restart all
ocm status
```

## Verify running image per container

```bash
for c in $(docker ps --format '{{.Names}}'); do
  echo "== $c";
  docker inspect "$c" --format '{{.Config.Image}}';
done
```

## Why this matters

`ocm restart all` alone only recreates containers from the image in `/opt/openclaw-agents.json`.
If that image tag still points at upstream/stale bytes, restarts will not roll out your fork changes.
