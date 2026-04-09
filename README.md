# Inception of Things (IoT) — Complete Guide

Welcome to the **Inception of Things** project! This repository contains a comprehensive three-part Kubernetes learning journey, starting from infrastructure setup and culminating in GitOps automation.

## Project Overview

This project teaches you Kubernetes fundamentals through hands-on implementation:
- **Part 1**: Build a multi-node Kubernetes cluster using Vagrant and K3s
- **Part 2**: Deploy multiple applications with load balancing and Ingress routing
- **Part 3**: Automate deployments using Argo CD and GitOps
- **Bonus**: Integrate GitLab into your cluster for complete CI/CD

---

## Quick Navigation

### [**Part 1: K3s and Vagrant**](p1/README.md)
Learn infrastructure-as-code and Kubernetes clustering. **For Part 1 detailed documentation, [read here](p1/README.md)**

### [**Part 2: K3s and Three Simple Applications**](p2/README.md)
Learn deployments, services, and Ingress routing. **For Part 2 detailed documentation, [read here](p2/README.md)**

### [**Part 3: K3d and Argo CD**](p3/README.md)
Learn GitOps and continuous deployment. **For Part 3 detailed documentation, [read here](p3/README.md)**

### [**Bonus: GitLab Integration** (Advanced)](bonus/README.md)
Learn self-hosted Git integration with Kubernetes. **For Bonus detailed documentation, [read here](bonus/README.md)**

---

## Project Structure

```
.
├── README.md                    # This file — navigation and overview
├── p1/                          # Part 1: Multi-node K3s cluster
│   ├── README.md                # [READ THIS for Part 1 details]
│   ├── Vagrantfile              # VM infrastructure definition
│   ├── scripts/
│   │   └── install.sh           # K3s installation script
│   └── confs/
│       └── [configuration files]
├── p2/                          # Part 2: Multi-app deployment
│   ├── README.md                # [READ THIS for Part 2 details]
│   ├── Vagrantfile              # Single-node K3s VM
│   ├── scripts/
│   │   └── install.sh           # K3s server setup
│   └── confs/
│       ├── namespace.yaml
│       ├── app1.yaml
│       ├── app2.yaml
│       ├── app3.yaml
│       └── ingress.yaml
├── p3/                          # Part 3: K3d & Argo CD
│   ├── README.md                # [READ THIS for Part 3 details]
│   ├── scripts/
│   │   └── install.sh           # K3d + Argo CD setup
│   └── confs/
│       ├── namespace.yaml
│       ├── argocd-app.yaml
│       └── app/
│           └── deployment.yaml
└── bonus/                       # Bonus: GitLab integration
    ├── README.md                # [READ THIS for Bonus details]
    ├── scripts/
    │   ├── install.sh
    │   └── gitlab-helper.sh
    └── confs/
        ├── namespace.yaml
        ├── gitlab-values.yaml
        └── app/
            └── deployment.yaml
```

---

## Part Details Summary

### Part 1: K3s and Vagrant

**What you'll learn:** Infrastructure-as-code, Kubernetes clustering, multi-node networking

**Platform constraints:**
- Latest stable Linux distribution
- Minimal resources: 1 CPU and 512-1024 MB RAM per VM
- Two machines: `{login}S` (192.168.56.110) and `{login}SW` (192.168.56.111)
- Passwordless SSH access
- K3s in controller/agent mode

**Expected outcome:** 2-node Kubernetes cluster ready for deployment

**For detailed setup, architecture, troubleshooting, and evaluation checklist → [Read Part 1 README](p1/README.md)**

---

### Part 2: K3s and Three Applications

**What you'll learn:** Deployments, Services, Ingress routing, load balancing, self-healing

**Runtime constraints:**
- Single VM running K3s in server mode
- IP: 192.168.56.110
- 3 applications deployed
- app2 with 3 replicas for load balancing

**Routing contract:**
| Host | App | Replicas |
|------|-----|----------|
| app1.com | App 1 | 1 |
| app2.com | App 2 | 3 |
| (default) | App 3 | 1 |

**Expected outcome:** Multi-app cluster with Ingress-based routing

**For detailed setup, manifests, testing, and evaluation checklist → [Read Part 2 README](p2/README.md)**

---

### Part 3: K3d and Argo CD

**What you'll learn:** GitOps, continuous deployment, Git-driven automation, declarative infrastructure

**Execution baseline:**
- K3d installed on the host machine
- Docker installed and operational
- Public GitHub repository with deployment manifests
- Two application versions (v1, v2)

**Architecture:**
- `argocd` namespace for Argo CD
- `dev` namespace for the application
- Automatic sync when GitHub repository is updated
- Application versioning with Docker tags

**Expected outcome:** GitOps-driven deployment with automatic sync from GitHub

**For detailed setup, GitHub integration, GitOps workflow, and evaluation checklist → [Read Part 3 README](p3/README.md)**

---

### Bonus: GitLab Integration

**What you'll learn:** Self-hosted Git, enterprise GitOps, Helm deployment

**Requirements:**
- Latest GitLab from official distribution
- GitLab running locally in the cluster
- Full Part 3 functionality preserved
- Dedicated `gitlab` namespace

**Eligibility:** Only evaluated if all mandatory parts (1, 2, 3) are flawless

**For detailed setup, GitLab configuration, and troubleshooting → [Read Bonus README](bonus/README.md)**

---

## Learning Path

### For Beginners (New to Kubernetes)
**Recommended order:** Part 1 → Part 2 → Part 3 → Bonus

Start with [Part 1](p1/README.md) to understand cluster architecture, then progress through [Part 2](p2/README.md) to learn application deployment, [Part 3](p3/README.md) for automation, and finish with [Bonus](bonus/README.md) for advanced concepts.

### For Intermediate Users (Familiar with Kubernetes)
**Recommended order:** Part 2 → Part 3 → Bonus

Skip Part 1 or review it quickly, then focus on [Part 2](p2/README.md) for Ingress and routing, [Part 3](p3/README.md) for GitOps, and [Bonus](bonus/README.md) for self-hosted Git integration.

### For Advanced Users (Kubernetes experts)
**Jump to:** [Part 3](p3/README.md) & [Bonus](bonus/README.md)

Focus on the advanced topics: Argo CD patterns, GitOps best practices, and complex GitLab integration.

---

## System Requirements

- **Vagrant** (v2.3.0+)
- **VirtualBox, VMware, or Parallels** (VM provider)
- **Docker** (for Part 3 & Bonus)
- **kubectl** (optional, can run inside VMs)
- **Git** (for cloning this repo)
- **2-4 GB RAM** minimum (4+ GB recommended)
- **20-50 GB free disk space** (depending on which parts you complete)

### Operating Systems Supported
- macOS (Intel & Apple Silicon)
- Linux (Ubuntu, Debian, CentOS, Fedora)
- Windows (with WSL2 + VirtualBox)

---

## Quick Start (TL;DR)

### Part 1
```bash
cd p1
vagrant up
vagrant ssh YOUR_LOGINS
kubectl get nodes  # Should show 2 nodes
```

### Part 2
```bash
cd p2
vagrant up
kubectl apply -f confs/
kubectl get ingress  # Should show routing rules
```

### Part 3
```bash
cd p3
./scripts/install.sh
# Push confs to GitHub, Argo CD will auto-deploy
```

---

## Key Concepts Glossary

### Core Kubernetes Terms

**Pod**: The smallest deployable unit; usually contains one container.

**Deployment**: A controller that ensures N replicas of your pod are always running.

**Service**: A stable endpoint for accessing pods (abstracts away IP churn).

**Ingress**: Routes external HTTP(S) traffic into the cluster based on hostname/path.

**Namespace**: Virtual cluster within the physical cluster (resource isolation).

**kubectl**: Command-line tool for managing your Kubernetes cluster.

### Project-Specific Terms

**K3s**: Lightweight Kubernetes distribution (single binary, minimal dependencies).

**K3d**: K3s running inside Docker containers (perfect for local development).

**Argo CD**: GitOps controller that automatically syncs your cluster with Git.

**Vagrant**: Infrastructure-as-code tool for automating VM creation.

**GitOps**: Practice of using Git as the single source of truth for infrastructure.

---

## Troubleshooting Quick Links

### [Part 1 Troubleshooting](p1/README.md#7-common-issues-and-fixes-troubleshooting)
- Vagrant hangs on `vagrant up`
- VMs created but K3s didn't install
- `kubectl get nodes` shows only 1 node

### [Part 2 Troubleshooting](p2/README.md#8-common-issues-and-fixes-troubleshooting)
- Ingress requests get 404
- app2 shows fewer than 3 replicas
- Cannot access services from host machine

### [Part 3 Troubleshooting](p3/README.md#10-common-issues-and-fixes-diagnostic-guide)
- Argo CD status is Unknown
- Application not syncing
- Port-forward returns NotFound

---

## Important  Criteria

**Part 1 Checklist:**
- ✅ 2 VMs created with correct names and IPs
- ✅ K3s cluster with 2 nodes both Ready
- ✅ Passwordless SSH working on both machines
- ✅ kubectl can query the cluster

**Part 2 Checklist:**
- ✅ 1 VM running K3s in server mode
- ✅ 3 applications deployed (app1, app2, app3)
- ✅ app2 has exactly 3 replicas running
- ✅ Ingress routing to correct apps based on hostname
- ✅ Default backend working for unknown hosts

**Part 3 Checklist:**
- ✅ K3d cluster running locally
- ✅ Argo CD managing a GitHub repository
- ✅ 2 namespaces created: argocd and dev
- ✅ Application versioning with v1 and v2 tags
- ✅ GitOps sync working (change Git → cluster updates automatically)


## Additional Resources

### Official Documentation
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [K3s Documentation](https://docs.k3s.io/)
- [K3d Documentation](https://k3d.io/)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Vagrant Documentation](https://www.vagrantup.com/docs)
- [Wil's Playground Application](https://hub.docker.com/r/wil42/playground)

### Learning Resources
- [Kubectl cheat sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [K3s vs K3d vs Kubernetes](https://docs.k3s.io/)
- [GitOps Guide](https://www.gitops.tech/)

---

## Tips for Success

1. **Read the full README for each part** before starting—not just the quick start
2. **Understand concepts** before copy-pasting commands
3. **Keep logs handy**: `journalctl -u k3s`, `kubectl logs`, `kubectl describe pod`
4. **Test incrementally**: After each major step, verify it worked
5. **Use verbose flags**: `kubectl get nodes -o wide`, `vagrant up --verbose`
6. **Document your setup**: Note your login, IP addresses, hostnames for reference
7. **Screenshots matter**: Take them as you go, not at the end

---

## Getting Help

- **Check the Troubleshooting section** in each part's README first
- **Review the architecture diagrams** to understand component relationships
- **Read error messages carefully**—Kubernetes and Vagrant provide helpful diagnostics
- **Check system logs**: `journalctl`, `dmesg`, `docker logs`
- **Google the error message**—chances are someone else hit it

---

## Starting Your Journey

→ **[Start with Part 1 README](p1/README.md)** if you're new  
→ **[Jump to Part 2 README](p2/README.md)** if you have Kubernetes experience  
→ **[Go to Part 3 README](p3/README.md)** if you want GitOps right now  

Good luck! 🚀

---
## Team

This project was delivered as a team effort:
- khammadi: https://github.com/khammadi
- alagmiri: https://github.com/AmalLAGMIRI

**Project**: Inception of Things (IoT) — System Administration  
**Difficulty**: Intermediate to Advanced  
**Date**: March 2026
