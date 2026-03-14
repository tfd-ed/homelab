# Kubernetes Playbooks

Kubernetes cluster deployment and configuration.

## Playbooks

### k3s-cluster-setup.yml
**Purpose:** Deploy complete K3s Kubernetes cluster with 1 master and 2 workers  
**Target:** k8s-master, k8s-worker-1, k8s-worker-2  
**Usage:** `ansible-playbook playbooks/kubernetes/k3s-cluster-setup.yml`

**Features:**
- K3s v1.28.8 installation
- Master node with control plane
- Worker nodes auto-join cluster
- Traefik disabled (use ingress-nginx)
- ingress-nginx controller (v1.10.0 baremetal)
- Docker registry mirror configuration
- Kubeconfig for remote access
- kubectl access for ubuntu user

**Post-installation:**
```bash
# Verify cluster
export KUBECONFIG=./kubeconfig
kubectl get nodes
kubectl get pods -A

# Access from anywhere
export KUBECONFIG=/path/to/homelab-journey/kubeconfig
```

**Components installed:**
- K3s control plane (master)
- K3s agent (workers)
- ingress-nginx controller
- Container registry configuration

**Configuration:**
- **Master:** 192.168.100.201 (2 CPU, 4GB RAM)
- **Worker-1:** 192.168.100.202 (4 CPU, 14GB RAM)
- **Worker-2:** 192.168.100.203 (4 CPU, 14GB RAM)
- **Registry:** registry.homelab.local → 192.168.100.240:5000

## Pre-requisites

Before running:
1. VMs must be provisioned (Terraform)
2. SSH access configured
3. Docker installed (if using Docker alongside K3s)

## Helper Scripts

Quick setup from project root:
```bash
./setup-k8s-complete.sh
```

## Related Playbooks

After Kubernetes is running:
- Deploy applications: [../services/](../services/)
- Setup monitoring: [../services/monitoring-setup.yml](../services/monitoring-setup.yml)
- Configure remote access: [../networking/](../networking/)

## Documentation

- [K8s Management Guide](../../../k8s/README.md)
- [Quick Reference](../../../QUICK_REFERENCE.md)
