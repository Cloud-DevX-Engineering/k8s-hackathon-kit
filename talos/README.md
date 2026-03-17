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
| Kubernetes | v1.35.2 |
| Provisioner | Docker |
| Webapp | 3× nginx replicas with hostname display |
| Load balancer | nginx-lb (round-robin, NodePort 30090) |
| Windows access | `http://localhost:8080` via socat |

## Cluster Details

| Property | Value |
|----------|-------|
| Cluster name | `local-talos` |
| kubectl context | `admin@local-talos` |
| talosctl context | `local-talos` |
| Worker IP | `10.5.0.3` |
| NodePort (LB) | `30090` |
| Windows URL | `http://localhost:8080` |

## Useful Commands

```bash
# Nodes and pods
kubectl get nodes
kubectl get pods -A
kubectl get pods -o wide

# Scale webapp up/down
kubectl scale deployment webapp --replicas=5

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
    → nginx-lb pod (NodePort 30090)
      → kube-proxy round-robin
        → webapp pod 1 (nginx:alpine)
        → webapp pod 2 (nginx:alpine)
        → webapp pod 3 (nginx:alpine)
```

## Notes

- WSL2 does not persist running processes across Windows restarts — always run `./start-talos.sh` after a reboot
- `dockerd` is started manually (no systemd in WSL2) — `start-talos.sh` handles this
- The webapp page auto-refreshes every 3 seconds and shows which pod served the request
