# k8s-hackathon-kit

Everything you need to run a Kubernetes hackathon or workshop on WSL2 — a local Talos cluster, an AI-powered assistant, and scripts to get from zero to `kubectl` in minutes.

## What's Inside

```
k8s-hackathon-kit/
├── talos/                  Local Talos Kubernetes cluster (Docker provisioner on WSL2)
│   ├── install-talos.sh    First-time setup: installs talosctl + kubectl, creates cluster
│   ├── start-talos.sh      Day-to-day: resumes or creates cluster
│   └── stop-talos.sh       Stop cluster (preserves data)
├── openclaw/               OpenClaw AI agent setup
│   ├── setup-openclaw-wsl2.sh    Full setup: creates openclaw user, installs Node.js + OpenClaw
│   └── azure-proxy/        Proxy for Azure-hosted models (Mistral, Kimi, Grok)
├── LICENSE
└── README.md
```

## Prerequisites

- **Windows** with WSL2 (Ubuntu)
- **Docker** installed and running in WSL2 (`sudo systemctl start docker`)
- User in the docker group (`sudo usermod -aG docker $USER`)
- systemd enabled in WSL2 (the setup script will handle this if needed)

## Quick Start

### 1. Set up the Kubernetes cluster

```bash
cd talos
chmod +x *.sh
./install-talos.sh      # First time: installs talosctl + kubectl, creates cluster
./start-talos.sh        # Day-to-day: resumes or creates cluster
```

### 2. (Optional) Set up OpenClaw AI agent

```bash
cd openclaw
chmod +x setup-openclaw-wsl2.sh
sudo ./setup-openclaw-wsl2.sh
```

This single script creates a dedicated `openclaw` user, installs Homebrew, Node.js, and OpenClaw under it. When it finishes, follow the printed next steps:

```bash
# Switch to the openclaw user (requires machinectl for a proper systemd session)
sudo machinectl shell openclaw@.host

# Run the interactive onboarding wizard
openclaw onboard --install-daemon
```

> ⚠️ **Important:** Do NOT use `sudo -iu openclaw`. It doesn't create a proper systemd user session, which breaks the gateway daemon. Always use `machinectl`.

OpenClaw runs as a systemd user service under the `openclaw` account — isolated from your main user, accessible at http://localhost:18789.

### 3. (Optional) Azure model proxy

If you're using Azure-hosted models (Mistral, Kimi, Grok), see [`openclaw/azure-proxy/README.md`](openclaw/azure-proxy/README.md).

## Day-to-Day Usage

```bash
# Start cluster
./talos/start-talos.sh

# Stop cluster (preserves data)
./talos/stop-talos.sh

# Check nodes
kubectl get nodes

# Full destroy (removes all data)
sudo -E talosctl cluster destroy --name local-talos --provisioner docker
```

## Notes

- WSL2 doesn't persist Docker containers across Windows restarts — run `start-talos.sh` after each reboot
- `sudo -E` is required when creating/destroying the cluster
- OpenClaw daemon auto-starts with WSL2 once installed (via systemd linger)

## Links

- [Talos Linux](https://www.talos.dev/)
- [OpenClaw Docs](https://docs.openclaw.ai)
