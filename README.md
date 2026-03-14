# Inception-of-Things (IoT)

Inception-of-Things is a System Administration project that models a practical Kubernetes adoption path in three controlled stages: cluster fundamentals, ingress-based service exposure, and GitOps-driven delivery.

## Overview

The project is structured to demonstrate how infrastructure maturity evolves:
- From manually provisioned virtual machines and basic cluster topology
- To service routing and workload scaling inside Kubernetes
- To declarative delivery with automated reconciliation through Argo CD

The stack combines Vagrant, K3s, K3d, Docker, kubectl, and Argo CD to represent a realistic progression from local infrastructure management to platform operations.

## Engineering Intent

- **Operational clarity**: each part isolates one core capability and its validation criteria.
- **Reproducibility**: infrastructure and deployment artifacts are versioned and deterministic.
- **Declarative control**: desired state is described in manifests and continuously reconciled.
- **Production mindset**: naming, networking, access, and rollout behavior are treated as first-class concerns.

## Project Structure

```
.
├── p1/
│   ├── Vagrantfile
│   ├── scripts/
│   └── confs/
├── p2/
│   ├── Vagrantfile
│   ├── scripts/
│   └── confs/
├── p3/
│   ├── scripts/
│   └── confs/
└── bonus/
    ├── Vagrantfile
    ├── scripts/
    └── confs/
```

## Mandatory Scope

### Part 1: K3s on Vagrant (Control Plane + Agent)

Part 1 establishes the baseline cluster architecture on two virtual machines.

**Why this part exists:**
- It validates node role separation (controller vs agent).
- It confirms deterministic networking and host-level access.
- It ensures Kubernetes tooling is available across all nodes for operations.

**Platform constraints:**
- Latest stable version of the selected Linux distribution
- Minimal resources per VM: 1 CPU and 512-1024 MB RAM
- Hostnames derived from team login

**Machine specifications:**

| Machine | Hostname | IP Address | K3s Mode |
|---------|----------|------------|----------|
| Server | `<login>S` | 192.168.56.110 | Controller |
| ServerWorker | `<login>SW` | 192.168.56.111 | Agent |

**Operational characteristics:**
- Dedicated IP on the primary network interface
- Passwordless SSH access
- `kubectl` available on both machines

### Part 2: K3s Ingress with Three Applications

Part 2 models service multiplexing through host-based ingress on a single K3s server.

**Why this part exists:**
- It demonstrates Layer-7 routing with host headers.
- It validates horizontal scaling behavior on one workload.
- It proves multiple apps can share one cluster ingress endpoint cleanly.

**Runtime constraints:**
- Single VM running K3s in server mode
- Machine name: `<login>S`
- IP address: 192.168.56.110

**Routing contract:**

| HOST | Application | Replicas |
|------|-------------|----------|
| app1.com | Application 1 | 1 |
| app2.com | Application 2 | 3 |
| default | Application 3 | 1 |

**Ingress expectations:**
- Application access is selected by `HOST` header to 192.168.56.110
- Ingress resources define routing behavior
- Application 2 runs with exactly 3 replicas

### Part 3: K3d + Argo CD (GitOps Delivery)

Part 3 shifts from VM-centric setup to containerized Kubernetes and declarative continuous delivery.

**Why this part exists:**
- It demonstrates Git as the source of truth for deployment state.
- It validates automatic reconciliation from repository changes.
- It introduces environment separation through namespace boundaries.

**Execution baseline:**
- K3d installed on the VM
- Docker installed and operational
- Installation script available for required packages

**Namespace model:**
1. **argocd** - Control namespace for Argo CD
2. **dev** - Target namespace for the application

**Application delivery model:**
- Public GitHub repository contains deployment manifests
- Repository name includes one team member login
- Two tagged application versions are available (`v1`, `v2`)
- Repository changes trigger Argo CD sync and rollout updates

**Application options:**
1. Use `wil42/playground` from Docker Hub (port 8888)
2. Use a custom application image hosted in a public Docker Hub repository

**Verification commands:**
```bash
# Validate namespaces
kubectl get ns

# Validate workload presence in dev
kubectl get pods -n dev

# Validate exposed application version
curl http://localhost:8888/
```

## Bonus Scope

The bonus introduces local GitLab as the GitOps source while preserving all Part 3 outcomes.

**Why this extension matters:**
- It validates self-hosted SCM integration with the Kubernetes delivery path.
- It reduces dependency on external hosted services.

**Bonus requirements:**
- Latest GitLab version from official distribution
- GitLab running locally
- Cluster integration configured for GitLab workflows
- Dedicated `gitlab` namespace
- Full Part 3 behavior preserved with local GitLab as source
- Helm or equivalent tooling allowed

> Bonus assessment is valid only when all mandatory parts are fully compliant.

## Delivery Rules

- All implementation runs in virtual machines
- Configuration is organized at repository root
- Mandatory scope lives in `p1`, `p2`, and `p3`
- Optional scope lives in `bonus`
- Automation scripts are stored in `scripts/`
- Kubernetes and related configs are stored in `confs/`

## Technology Roles

- **Vagrant** - deterministic VM provisioning
- **K3s** - lightweight Kubernetes runtime
- **K3d** - K3s lifecycle in Docker
- **Argo CD** - declarative GitOps controller
- **Docker** - container runtime dependency for K3d
- **kubectl** - cluster operations interface
- **GitLab (Bonus)** - self-hosted source control and CI/CD integration point

## Resources

- [K3s Documentation](https://docs.k3s.io/)
- [K3d Documentation](https://k3d.io/)
- [Vagrant Documentation](https://www.vagrantup.com/docs)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Wil's Playground Application](https://hub.docker.com/r/wil42/playground)

## Network Notes

Modern Linux distributions commonly expose predictable network interface names such as `enp0s8` and `enp0s9`, replacing legacy names like `eth0` and `eth1`.

**Reference commands:**
- Linux: `ip a` or `ip a show <interface_name>`
- macOS: `ifconfig`

Interface names are environment-specific and are mapped to the actual host and guest configuration.

## Submission Context

- Submission is handled through a Git repository
- Folder naming and structure are part of the evaluation
- Mandatory scope remains in `p1`, `p2`, `p3`
- Bonus scope, when present, remains in `bonus`
- Evaluation is performed on the assessed group machine

## Quality Bar

- Kubernetes, K3s, and K3d documentation usage is expected
- Vagrant and network configuration follow current best practices
- Passwordless operational access is functional
- End-to-end validation is required before assessment
- Bonus eligibility depends on a flawless mandatory implementation

---

**Project Date:** March 2026  
**Course:** System Administration  
**Difficulty:** Intermediate to Advanced
