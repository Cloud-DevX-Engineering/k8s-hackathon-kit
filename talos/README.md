# Talos Local Cluster — WSL2

A local Talos Kubernetes cluster using the Docker provisioner on WSL2 Ubuntu. Designed for hackathons, workshops, and local development — up and running in under 10 minutes.

## Scripts

| Script | Purpose |
|---|---|
| `install-talos.sh` | First-time install: installs talosctl, kubectl, creates the cluster |
| `start-talos.sh` | Start the cluster (resumes existing containers, or creates new) |
| `stop-talos.sh` | Stop the cluster (preserves containers and data) |

## Quick Start

```bash
chmod +x *.sh

# First time only
./install-talos.sh

# Day-to-day
./start-talos.sh    # Start
./stop-talos.sh     # Stop
```

## Cluster Details

| Property | Value |
|---|---|
| Cluster name | `local-talos` |
| Provisioner | Docker |
| kubectl context | `admin@local-talos` |
| talosctl context | `local-talos` |

## Prerequisites

- WSL2 Ubuntu with Docker running (`sudo systemctl start docker`)
- User in the docker group
- (Optional) OpenClaw system user — see `../openclaw/setup-openclaw-user.sh`

## Useful Commands

```bash
# Check nodes
kubectl get nodes

# All pods
kubectl get pods -A

# Talos cluster info
talosctl config info

# Full destroy (removes all data)
sudo -E talosctl cluster destroy --name local-talos --provisioner docker
```

## Notes

- WSL2 doesn't persist Docker containers across Windows restarts — use `start-talos.sh` after each reboot
- `sudo -E` is required when creating/destroying the cluster to pass environment through
- Docker must be running before starting the cluster
