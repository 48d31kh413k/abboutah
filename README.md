# Inception-of-Things (IoT)

A System Administration project focused on learning Kubernetes fundamentals using K3s, K3d, Vagrant, and Argo CD.

##  Overview

This project aims to deepen knowledge in Kubernetes by using K3d and K3s with Vagrant. You will learn how to set up personal virtual machines, configure K3s with Ingress, and implement continuous integration with Argo CD.

##  Objectives

- Set up virtual machines with Vagrant
- Install and configure K3s in controller and agent modes
- Deploy applications with K3s Ingress
- Use K3d for simplified Kubernetes management
- Implement continuous integration with Argo CD

##  Project Structure

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

## Mandatory Parts

### Part 1: K3s and Vagrant

Set up 2 virtual machines using Vagrant with K3s installed.

**Requirements:**
- Use the latest stable version of your chosen distribution
- Minimal resources: 1 CPU and 512-1024 MB RAM
- Machine names based on team member login

**Machine Specifications:**

| Machine | Hostname | IP Address | K3s Mode |
|---------|----------|------------|----------|
| Server | `<login>S` | 192.168.56.110 | Controller |
| ServerWorker | `<login>SW` | 192.168.56.111 | Agent |

**Features:**
- Dedicated IP on primary network interface
- SSH access without password
- kubectl installed on both machines

### Part 2: K3s and Three Simple Applications

Deploy 3 web applications accessible via different HOSTs on a single K3s server.

**Requirements:**
- Single virtual machine with K3s in server mode
- Machine name: `<login>S`
- IP: 192.168.56.110

**Application Routing:**

| HOST | Application | Replicas |
|------|-------------|----------|
| app1.com | Application 1 | 1 |
| app2.com | Application 2 | 3 |
| default | Application 3 | 1 |

**Configuration:**
- Access applications by HOST header to IP 192.168.56.110
- Configure Ingress for routing
- Application 2 must have 3 replicas

### Part 3: K3d and Argo CD

Set up a continuous integration pipeline using K3d and Argo CD (without Vagrant).

**Requirements:**
- Install K3d on your virtual machine
- Docker must be installed
- Create an installation script for all necessary packages

**Namespaces:**
1. **argocd** - Dedicated to Argo CD
2. **dev** - Contains the application deployed by Argo CD

**Application Deployment:**
- Use a public GitHub repository with configuration files
- Repository name must include a team member's login
- Application must have two versions (v1 and v2) using tags
- Changes in GitHub repo should trigger automatic updates

**Application Options:**
1. Use Wil's pre-made application: `wil42/playground` on Docker Hub (port 8888)
2. Create your own application with a public Docker Hub repository

**Testing:**
```bash
# Check namespaces
kubectl get ns

# Check pods in dev namespace
kubectl get pods -n dev

# Verify application version
curl http://localhost:8888/
```

## Bonus Part

Add GitLab to Part 3 setup.

**Requirements:**
- Latest version of GitLab from official website
- GitLab must run locally
- Configure GitLab to work with your cluster
- Create dedicated namespace: `gitlab`
- All Part 3 functionality must work with local GitLab
- Use helm or other tools as needed

> The bonus part will only be assessed if the mandatory part is flawless.

## General Guidelines

- All work must be done in virtual machines
- Configuration files organized in folders at repository root
- Mandatory parts in folders: `p1`, `p2`, `p3`
- Bonus part in folder: `bonus`
- Scripts go in `scripts/` folder
- Configuration files go in `confs/` folder
- Use any tools for host VM setup and Vagrant provider

## Technologies

- **Vagrant** - Virtual machine management
- **K3s** - Lightweight Kubernetes distribution
- **K3d** - K3s in Docker
- **Argo CD** - Declarative GitOps continuous delivery
- **Docker** - Container platform
- **kubectl** - Kubernetes command-line tool
- **GitLab** (Bonus) - DevOps platform

## Resources

- [K3s Documentation](https://docs.k3s.io/)
- [K3d Documentation](https://k3d.io/)
- [Vagrant Documentation](https://www.vagrantup.com/docs)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Wil's Playground Application](https://hub.docker.com/r/wil42/playground)

## 🔍 Network Configuration Notes

Modern Linux distributions use predictable network interface names (e.g., `enp0s8`, `enp0s9`) instead of `eth0`/`eth1`.

**Check network configuration:**
- Linux: `ip a` or `ip a show <interface_name>`
- macOS: `ifconfig`

Adapt commands according to your system's actual interface names.

## Submission

- Submit via Git repository
- Ensure correct folder and file names
- Mandatory parts in `p1`, `p2`, `p3` folders
- Optional bonus in `bonus` folder
- Evaluation happens on the evaluated group's computer

## Important Notes

- Read extensive documentation on K8s, K3s, and K3d
- Follow modern Vagrant practices
- Ensure SSH access without passwords
- Test all configurations before submission
- The bonus requires a flawless mandatory part

---

**Project Date:** March 2026 
**Course:** System Administration  
**Difficulty:** Intermediate to Advanced
