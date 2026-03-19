# NemoClaw Setup Scripts

Scripts to install and configure NemoClaw with Nebius inference on WSL2.

## What is NemoClaw?

NemoClaw provides sandboxed AI agent environments using OpenShell. Each sandbox runs with Landlock + seccomp + netns isolation and network policies that control which endpoints the agent can reach.

## Prerequisites

- WSL2 with Docker running
- Node.js (for nemoclaw CLI)
- Nebius API key from https://tokenfactory.nebius.com/
- NVIDIA API key from https://build.nvidia.com/settings/api-keys (for initial onboard only)

## Quick Start

```bash
# 1. Install NemoClaw and create sandbox
./setup-nemoclaw.sh

# 2. Configure Nebius as inference provider (uploads model config to sandbox automatically)
./setup-nebius.sh <YOUR_NEBIUS_API_KEY>

# 3. Finish setup inside the sandbox (script prints the exact commands)
nemoclaw huginn connect
python3 /tmp/update-model.py/<tempfile>    # path shown by setup-nebius.sh
openclaw tui
```

## Scripts

| Script | Description |
|---|---|
| `setup-nemoclaw.sh` | Installs CLI, frees ports, runs `nemoclaw onboard` |
| `setup-nebius.sh` | Creates Nebius provider, sets inference route, updates network policy |
| `nebius-network-policy.yaml` | Full sandbox policy with `api.tokenfactory.nebius.com` allowed |
| `update-openclaw-model.py` | Updates OpenClaw config inside sandbox to use Nebius model |
| `cleanup.sh` | Destroys sandbox and stops gateway |

## Architecture

```
Host (WSL2)
├── nemoclaw CLI
├── openshell CLI
└── Docker
    └── openshell-cluster-nemoclaw (k3s container)
        ├── OpenShell gateway (:8080, mTLS)
        └── Sandbox "huginn" (isolated)
            ├── OpenClaw TUI + agent
            ├── Network proxy (policy-enforced)
            └── inference.local → Nebius API (gateway-injected credentials)
```

## Key Learnings

- **Provider config key**: Use `OPENAI_BASE_URL` (not `base_url`) when creating an `openai`-type provider with a custom endpoint
- **Network policies**: Sandbox blocks all traffic not in the policy. Both the endpoint host AND the calling binary must be allowed
- **Inference routing**: Inside the sandbox, use `https://inference.local/v1` — the gateway injects API credentials automatically
- **Port conflicts**: Previous runs leave containers/SSH tunnels on ports 8080 and 18789 — clean up before re-running onboard

## Available Models (Nebius)

| Model | Context | Cost (in/out per 1M tokens) |
|---|---|---|
| Qwen/Qwen3.5-397B-A17B | 262K | $0.60 / $3.60 |
| Qwen/Qwen3-235B-A22B-Instruct-2507 | 262K | $0.20 / $0.60 |
| deepseek-ai/DeepSeek-V3.2 | 163K | $0.30 / $0.45 |
| moonshotai/Kimi-K2.5 | 262K | $0.50 / $2.50 |

## Common Commands

```bash
# Connect to sandbox
nemoclaw huginn connect

# Check status
nemoclaw huginn status

# View logs
openshell logs huginn

# Test inference from inside sandbox
curl -s https://inference.local/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"Qwen/Qwen3.5-397B-A17B","messages":[{"role":"user","content":"hello"}],"max_tokens":50}'

# Launch OpenClaw TUI (from inside sandbox)
openclaw tui

# Launch OpenShell TUI (from host)
openshell term

# Switch model
openshell inference set --provider nebius --model "deepseek-ai/DeepSeek-V3.2"
```
