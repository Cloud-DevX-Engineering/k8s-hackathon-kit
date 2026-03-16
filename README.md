# k8s-hackathon-kit

Everything you need to run a Kubernetes hackathon or workshop on WSL2 — a local Talos cluster, an AI-powered assistant, and scripts to get from zero to `kubectl` in minutes.

## What's Inside

```
k8s-hackathon-kit/
├── talos/        Local Talos Kubernetes cluster (Docker provisioner on WSL2)
├── openclaw/     OpenClaw AI agent setup (backlog management, cluster ops, coding)
├── LICENSE
└── README.md
```

## Prerequisites

- **Windows** with WSL2 (Ubuntu)
- **Docker** installed and running in WSL2 (`sudo systemctl start docker`)
- User in the docker group (`sudo usermod -aG docker $USER`)

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
chmod +x *.sh
sudo ./setup-openclaw-user.sh              # Creates dedicated 'openclaw' user with sudo + docker
sudo -u openclaw ./install-openclaw.sh     # Installs OpenClaw as the openclaw user
```

OpenClaw runs as a systemd user service under the `openclaw` account — isolated from your main user, with its own home directory, workspace, and Node.js install. Accessible at http://localhost:18789.

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
- OpenClaw daemon auto-starts with WSL2 once installed

## Links

- [Talos Linux](https://www.talos.dev/)
- [OpenClaw Docs](https://docs.openclaw.ai)
