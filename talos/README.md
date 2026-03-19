# Talos Local Cluster — WSL2

A local Talos Kubernetes cluster using the Docker provisioner on WSL2. Designed for hackathons, workshops, and local development.

## Quick Start

```bash
chmod +x *.sh

# First time only — installs talosctl, kubectl, creates cluster
./install-talos.sh

# After every WSL2/Windows restart
./start-talos.sh

# When done for the day
./stop-talos.sh
```

## What's Running

| Component | Details |
|-----------|---------|
| Cluster | `local-talos` (1 control-plane + 1 worker) |
| Kubernetes | Latest (determined by talosctl at install time) |
| Provisioner | Docker |
| Windows access | `http://localhost:8080` via socat → worker NodePort 30090 |

## Cluster Details

| Property | Value |
|----------|-------|
| Cluster name | `local-talos` |
| kubectl context | `admin@local-talos` |
| talosctl context | `local-talos` |
| Worker IP | Dynamic (discovered via `docker inspect`) |
| Windows URL | `http://localhost:8080` |

## Useful Commands

```bash
# Nodes and pods
kubectl get nodes
kubectl get pods -A
kubectl get pods -o wide

# Watch pods live
kubectl get pods -w

# Talos cluster info
talosctl config info

# Full destroy (removes all data — need to re-run install-talos.sh)
sudo -E talosctl cluster destroy docker --name local-talos
```

## Architecture

```
Windows browser
  → localhost:8080 (socat, WSL2)
    → Worker node (NodePort 30090)
      → Your deployed services
```

## Notes

- WSL2 does not persist running processes across Windows restarts — always run `./start-talos.sh` after a reboot
- `start-talos.sh` starts dockerd if needed and restores the socat port-forward
- Worker nodes come back cordoned after a container restart — `start-talos.sh` uncordons them automatically
