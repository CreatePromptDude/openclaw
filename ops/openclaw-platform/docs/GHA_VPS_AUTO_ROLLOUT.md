# GHA → VPS Auto Rollout (Security Best Practices)

This workflow auto-deploys latest `main` when OpenClaw runtime or platform files change.

Workflow file: `.github/workflows/vps-auto-rollout.yml`

## Trigger Scope

Auto-rollout runs on push to `main` when any of these paths change:

- `src/**`
- `scripts/**`
- `ops/openclaw-platform/**`
- `package.json`
- `pnpm-lock.yaml`

## Required GitHub Secrets

Store in repo/org secrets:

- `VPS_HOST` — hostname or IP of VPS
- `VPS_USER` — dedicated deploy user (non-root preferred)
- `VPS_PORT` — SSH port (optional, default 22)
- `VPS_DEPLOY_SSH_KEY` — private key for deploy user (ed25519)
- `VPS_KNOWN_HOSTS` — pinned host key line(s) from `ssh-keyscan -t ed25519 <host>`

## Security Controls (Mandatory)

1. **Dedicated deploy principal**
   - Use a separate SSH keypair and user for CI deploys.
   - Do not reuse personal keys.

2. **Strict host key pinning**
   - `StrictHostKeyChecking=yes`
   - `known_hosts` is provided via secret (`VPS_KNOWN_HOSTS`) and not discovered at runtime.

3. **Least privilege**
   - Deploy user should only have permissions needed to run:
     - `cd ~/prompt/createprompt`
     - `bash scripts/deploy-fork-fleet.sh`
     - `ocm restart all`
   - Prefer sudoers command allowlist over full sudo access.

4. **Branch protection + environment protection**
   - Protect `main` with required checks.
   - Require approvals for `production` environment if desired.

5. **Replay-safe deployments**
   - Workflow uses concurrency lock (`vps-auto-rollout-main`) to avoid overlapping rollouts.

## Remote Rollout Command

The workflow executes on VPS:

```bash
cd ~/prompt/createprompt
bash scripts/deploy-fork-fleet.sh
```

That script:
1. pulls latest `main`
2. builds a SHA-tagged image
3. stamps `/opt/openclaw-agents.json` with image + `OPENCLAW_PROMPT_DNA_VERSION`
4. restarts all agents via `ocm restart all`
5. prints running container images

## Hardening Optional (Recommended)

- Restrict SSH key in `authorized_keys` with:
  - `from="<github-actions-egress-cidr-if-managed>"` (if feasible)
  - `command="/usr/local/bin/deploy-openclaw-fleet"`
  - disable forwarding options (`no-port-forwarding,no-agent-forwarding,no-pty`)
- Emit deploy audit logs with commit SHA + actor + UTC timestamp.
- Add post-deploy health probe and fail workflow on unhealthy status.
