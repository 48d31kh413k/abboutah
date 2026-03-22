# Part 1 Documentation: K3s and Vagrant (Cluster Foundation)

**TL;DR:** Part 1 sets up a two-node Kubernetes cluster using Vagrant and K3s. One machine runs K3s in controller mode (server), the second runs it in agent mode (worker). This creates a distributed cluster where the controller manages workload scheduling.

This document explains:
- **What** Part 1 does and why it matters
- **How** the Vagrant setup works
- **Why** we use a controller and agent architecture
- **How to** run, verify, and troubleshoot the setup
- **Key design decisions** and best practices

## Table of Contents

1. [What Part 1 is doing (The Big Picture)](#1-what-part-1-is-doing-the-big-picture)
2. [Why each component exists (Architecture Explained)](#2-why-each-component-exists-architecture-explained)
3. [Files and responsibilities (Project Layout)](#3-files-and-responsibilities-project-layout)
4. [Vagrant configuration deep dive](#4-vagrant-configuration-deep-dive)
5. [How to run everything (Step-by-Step)](#5-how-to-run-everything-step-by-step)
6. [Verifying the cluster (Testing and Validation)](#6-verifying-the-cluster-testing-and-validation)
7. [Common issues and fixes (Troubleshooting)](#7-common-issues-and-fixes-troubleshooting)
8. [Architecture Overview (Cluster Topology)](#8-architecture-overview-cluster-topology)
9. [Key Concepts (Learning the Fundamentals)](#9-key-concepts-learning-the-fundamentals)
10. [Quick Reference Commands](#10-quick-reference-commands)


---

## 1) What Part 1 is doing (The Big Picture)

**The Challenge:** You need to understand Kubernetes infrastructure from the ground up. Not just "use a managed cluster," but actually build one.

**The Solution:** Vagrant + K3s creates a reproducible, multi-node Kubernetes cluster on your local machine.

**Part 1 Flow:**
```
Vagrant creates 2 Linux VMs → K3s installs on both → Server becomes controller 
→ Worker joins cluster → kubectl connects and manages both → You have a 2-node cluster
```

**What you'll learn:**
- How Kubernetes controllers and agents communicate
- What happens when you `kubectl apply` a deployment (the server schedules it, agents run it)
- How to set up networking between machines (predictable IPs, SSH)
- How infrastructure-as-code (Vagrant) enables reproducibility

---

## 2) Why each component exists (Architecture Explained)

### Vagrant
**What it is:** Infrastructure-as-code tool that automates VM creation.
**Why it's here:** Instead of manually clicking buttons to create VMs (slow, error-prone), Vagrant reads a file and creates identical VMs every time.
**For you:** `vagrant up` creates both machines with your exact specifications in seconds.

### Linux Distribution (Your Choice)
**What it is:** The guest operating system for each VM.
**Why it's here:** K3s runs on Linux. You choose the distribution (Ubuntu, Debian, CentOS, etc.), but Vagrant provisions it automatically.
**For you:** All package management, networking, and system utilities run here.

### K3s Controller (Server Node)
**What it is:** The Kubernetes brain. Stores cluster state, schedules workloads, manages node health.
**Why it's here:** Every K3s cluster needs exactly one controller (or HA setup for production, but that's beyond Part 1).
**Responsibilities:**
  - Runs the API server (your `kubectl` commands hit this)
  - Schedules pods onto healthy nodes
  - Stores cluster state in etcd (embedded database)
  - Manages node certificates and cluster networking
**For you:** This is the "central command" of your cluster.

### K3s Agent (Worker Node)
**What it is:** A lightweight worker that executes containers scheduled by the controller.
**Why it's here:** A single-node cluster isn't interesting. Adding an agent node teaches you how the controller and agent communicate.
**Responsibilities:**
  - Runs containers (pods) scheduled by the controller
  - Reports node health back to the controller
  - Executes `kubelet` (the node agent that manages containers)
**For you:** When you deploy something, the controller might schedule it here.

### kubectl
**What it is:** The command-line client that speaks to the Kubernetes API server.
**Why it's here:** How you interact with your cluster. Essential for verifying that everything works.
**For you:** You'll use it to check nodes, run diagnostics, and prepare for Part 2.

### SSH passwordless setup
**What it means:** You can `ssh` into either VM without typing a password.
**Why it's important:** Container health checks, debugging, and manual interventions require SSH. Modern deployments automate this, but understanding manual SSH is foundational.
**For you:** Proves that both VMs are reachable and properly configured.

---

## 3) Files and responsibilities (Project Layout)

```
p1/
├── Vagrantfile           # Main infrastructure definition (VMs, resources, provisioning)
├── scripts/
│   ├── install.sh        # Automated K3s installation for both nodes
│   └── [other helpers]   # Any additional setup scripts
└── confs/
    ├── [Configuration files if needed]
    └── [For environment-specific settings]
```

### Vagrantfile
- Defines 2 virtual machines with names `{login}S` and `{login}SW`
- Sets IP addresses: 110 (controller), 111 (agent)
- Allocates minimal resources: 1 CPU, 512 MB RAM each
- Configures provider (VirtualBox, VMware, Parallels)
- Sets up SSH keys for passwordless login
- Runs provisioning scripts

### scripts/install.sh
- Installs K3s in controller mode on the first machine
- Installs K3s in agent mode on the second machine
- Retrieves the join token and configures the agent to join the cluster
- Installs kubectl (if needed on the host)
- Ensures the cluster is in a ready state

---

## 4) Vagrant configuration deep dive

### Machine definitions
```ruby
config.vm.define "YOUR_LOGINS" do |server|
  server.vm.hostname = "YOUR_LOGINS"
  server.vm.network "private_network", ip: "192.168.56.110"
  # Resources
  # Provider configuration
  # Provisioning
end
```

**Key points:**
- `config.vm.define` creates a named machine that you can target with `vagrant up YOUR_LOGINS`
- `vm.hostname` sets the machine's internal hostname (visible in `ip a` output)
- `vm.network "private_network"` creates a VirtualBox-only network isolated from the host (not NAT)
- IP addresses (110 and 111) must be on the same subnet for direct communication

### Resource allocation
- **1 CPU:** Sufficient for learning. More = faster cluster operations.
- **512 MB or 1024 MB RAM:** Minimum for K3s. 512 MB is tight; 1024 MB is safer.
- **Disk:** Default Vagrant box size (usually ~40 GB) is plenty.

### SSH key-based authentication
Vagrant automatically generates SSH keys and configures the VMs to accept them. This means:
- `vagrant ssh SERVER` works without a password
- Clustering scripts can SSH between nodes without a password
- Manual debugging requires no password entry

### Provisioning order
1. **Inline shell provisioning** (basic setup, repos, dependencies)
2. **Script provisioning** (complex operations like K3s installation)

Order matters: You must install packages before running K3s scripts.

---

## 5) How to run everything (Step-by-Step)

### Prerequisites
- Vagrant installed ([download here](https://developer.hashicorp.com/vagrant/install))
- VirtualBox, VMware, or Parallels installed (for VM hosting)
- 2-4 GB free RAM (for two VMs)
- 10+ GB free disk space
- macOS, Linux, or Windows (with WSL2)

### Launch the cluster
```bash
cd p1
vagrant up
# This will:
# 1. Download the base box (if not cached)
# 2. Create both VMs
# 3. Run provisioning scripts
# 4. Install K3s on both
# Total time: 5-10 minutes
```

### Verify both machines are running
```bash
vagrant status
# Output:
# YOUR_LOGINS               running (virtualbox)
# YOUR_LOGINS_SW            running (virtualbox)

vagrant ssh YOUR_LOGINS
# You should now be inside the server VM
exit
```

### Check the cluster from inside the server VM
```bash
vagrant ssh YOUR_LOGINS

# Once inside the VM:
kubectl get nodes
# Expected output:
# NAME                STATUS   ROLES                  AGE   VERSION
# YOUR_LOGINS         Ready    control-plane,master  XmYs  vX.Y.Z
# YOUR_LOGINS_SW      Ready    <none>                XmYs  vX.Y.Z

kubectl get pods --all-namespaces
# See system pods (coredns, metrics-server, etc.)
```

### Optional: Access kubectl from your host machine
Some setups copy the kubeconfig to the host. If configured:
```bash
export KUBECONFIG=$PWD/kubeconfig.yaml
kubectl get nodes
# From your host machine
```

---

## 6) Verifying the cluster (Testing and Validation)

### Checklist for Part 1 requirements

- [ ] Two VMs are created and running
- [ ] Server VM hostname: `{login}S`
- [ ] Worker VM hostname: `{login}SW`
- [ ] Server IP: 192.168.56.110
- [ ] Worker IP: 192.168.56.111
- [ ] SSH passwordless: `vagrant ssh {name}` works
- [ ] `kubectl get nodes` shows 2 nodes both in `Ready` state
- [ ] `kubectl` is installed and communicates with the cluster
- [ ] K3s controller is on the server machine
- [ ] K3s agent is on the worker machine

### Commands to verify each requirement
```bash
# 1. Check VMs are running
vagrant status

##### SCREENSHOT NEEDED HERE ###
# Capture: `vagrant status` output showing both VMs as "running"

# 2. Verify hostnames inside server
vagrant ssh YOUR_LOGINS
hostname  # Should output: YOUR_LOGINS
exit

# 3. Verify hostnames inside worker
vagrant ssh YOUR_LOGINS_SW
hostname  # Should output: YOUR_LOGINS_SW
exit

# 4. Verify IPs
vagrant ssh YOUR_LOGINS
ip a show enp0s8  # Or eth1, depending on your distribution
# Look for 192.168.56.110

vagrant ssh YOUR_LOGINS_SW
ip a show enp0s8
# Look for 192.168.56.111

##### SCREENSHOT NEEDED HERE ###
# Capture: `ip a` output from both VMs showing the correct IPs

# 5. Verify passwordless SSH
vagrant ssh YOUR_LOGINS  # Should work without prompting for password

# 6. Verify K3s cluster from server
vagrant ssh YOUR_LOGINS
kubectl get nodes
# Expected: 2 nodes, both Ready

kubectl get nodes -o wide
# Shows more detail: CPU, memory, kernel version

##### SCREENSHOT NEEDED HERE ###
# Capture: `kubectl get nodes` showing both nodes in Ready state

# 7. Verify K3s is running in controller mode on server
vagrant ssh YOUR_LOGINS
systemctl status k3s
# Should show "active (running)" and "server" mode

# 8. Verify K3s is running in agent mode on worker
vagrant ssh YOUR_LOGINS_SW
systemctl status k3s-agent
# Should show "active (running)"

##### SCREENSHOT NEEDED HERE ###
# Capture: systemctl status output from both machines

# 9. Verify system pods are running
vagrant ssh YOUR_LOGINS
kubectl get pods --all-namespaces
# You should see coredns, metrics-server, local-path-provisioner, etc.

##### SCREENSHOT NEEDED HERE ###
# Capture: `kubectl get pods --all-namespaces` showing system pods
```

---

## 7) Common issues and fixes (Troubleshooting)

### Issue: Vagrant hangs on `vagrant up`
**Cause:** Network issues during box download or provisioning script timeout.
**Fix:**
```bash
vagrant destroy -f
vagrant up

# Or enable increased timeout:
export VAGRANT_TIMEOUT=300  # 5 minutes
vagrant up
```

### Issue: VMs created but K3s didn't install
**Cause:** Provisioning script failed silently.
**Fix:**
```bash
vagrant ssh YOUR_LOGINS
sudo journalctl -u k3s -n 50  # Last 50 lines of K3s logs
# Look for errors in the output

# Manually run the install script:
sudo bash /path/to/scripts/install.sh
```

### Issue: `kubectl get nodes` shows 1 node only, or has "NotReady" status
**Cause:** Agent didn't join the cluster (networking, token, or firewall issue).
**Fix:**
```bash
# Check agent logs on worker VM
vagrant ssh YOUR_LOGINS_SW
sudo journalctl -u k3s-agent -n 50
# Look for "Successfully registered" or "failed to connect" messages

# Manually re-join:
sudo systemctl restart k3s-agent
sleep 10
vagrant ssh YOUR_LOGINS
kubectl get nodes  # Check again
```

### Issue: Machines can't ping each other
**Cause:** Network interface configuration mismatch (eth0 vs enp0s8).
**Fix:**
The Vagrantfile should specify the correct interface name. If machines still can't ping:
```bash
vagrant ssh YOUR_LOGINS
ping 192.168.56.111  # Try to reach the worker
# If it fails, check the network interface:
ip a
# Identify which interface has 192.168.56.110 and verify it's correct
```

### Issue: SSH key permission denied
**Cause:** Vagrant SSH key has wrong permissions.
**Fix:**
```bash
vagrant ssh-config YOUR_LOGINS
# This shows you the private key path. Then:
chmod 600 /path/to/private/key
vagrant ssh YOUR_LOGINS
```

---

## 8) Architecture Overview (Cluster Topology)

```
┌─────────────────────────────────────────────────────────┐
│ Your Host Machine (macOS / Linux / Windows)             │
│  (Has Vagrant and VirtualBox installed)                 │
└──────────────────┬──────────────────────────────────────┘
                   │
        ┌──────────┴──────────┐
        │                     │
    ┌───▼────────────┐   ┌───▼────────────┐
    │ K3s Controller │   │  K3s Agent     │
    │ (Server)       │   │  (Worker)      │
    │                │   │                │
    │ VM: YOUR_LOGINS│   │ VM: YOUR_LOGINS_SW│
    │ IP: 110        │   │ IP: 111        │
    │                │   │                │
    │ Runs:          │   │ Runs:          │
    │ - API server   │   │ - kubelet      │
    │ - Controller   │   │ - container    │
    │ - etcd (state) │   │ - agent        │
    │ - kubectl      │   │ - kubelet      │
    └───┬────────────┘   └───┬────────────┘
        │         Cluster Networking (vboxnet2)
        └────────┬──────────┘
                 │
        (10.42.x.x subnet for pods)
```

**Port 6443:** API server on controller communicates with agents
**Port 10250:** Kubelet on agent communicates with controller
**Network interface:** enp0s8, eth1, or equivalent (used for host-only networking)

---

## 9) Key Concepts (Learning the Fundamentals)

### Control Plane vs Data Plane
- **Control Plane:** The "brain"—stores state, schedules workloads (runs on your server)
- **Data Plane:** The "muscles"—executes containers (runs on your worker)

### Nodes
A "node" in Kubernetes is a machine (VM or physical) that runs containers.
- **Controller node (master):** Manages the cluster
- **Worker node (agent):** Executes workloads

### Pods
The smallest deployable unit in Kubernetes. Usually contains 1 container (but can have more).

### kubelet
A small agent running on every node. It talks to the control plane and starts/stops containers.

### etcd
A distributed database where Kubernetes stores all its state (node info, pod definitions, secrets, etc.).

### kubeconfig
A file that tells `kubectl` where to find your API server and what credentials to use.

---

## 10) Quick Reference Commands

```bash
# Vagrant commands
vagrant up                    # Start both VMs and provision
vagrant halt                  # Graceful shutdown
vagrant destroy               # Delete the VMs
vagrant destroy -f            # Force delete
vagrant status                # Show state of all VMs
vagrant ssh YOUR_LOGINS       # SSH into server
vagrant ssh YOUR_LOGINS_SW    # SSH into worker
vagrant reload                # Reboot both VMs

# kubectl commands (run these from inside the server VM)
kubectl get nodes             # List all nodes
kubectl get nodes -o wide     # More details
kubectl get pods --all-namespaces  # List all pods
kubectl describe node YOUR_LOGINS  # Detailed node info
kubectl logs -n kube-system pod-name  # Pod logs

# Network diagnostics (inside a VM)
ip a                          # List all interfaces
ip a show enp0s8              # Show a specific interface
ping 192.168.56.111           # Test connectivity
systemctl status k3s          # Check K3s service status
systemctl status k3s-agent    # Check agent status
journalctl -u k3s -n 50       # Last 50 lines of K3s logs
```

---

**Key Takeaway:** Part 1 teaches you the foundation of Kubernetes clustering. You're not managing a cloud provider's abstraction—you're understanding the actual coordinator (K3s) and how nodes join and communicate. This knowledge is essential before moving to Part 2 (multi-app deployment) and Part 3 (GitOps automation).
