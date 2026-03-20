# Part 3 Documentation: K3d + Argo CD (How and Why)

**TL;DR:** Part 3 demonstrates GitOps automation. You push code to GitHub, and Argo CD automatically updates your running application. No manual `kubectl apply` commands needed—the cluster constantly reconciles with Git.

This document explains:
- **What** Part 3 does and why it matters
- **How** each component works together
- **Why** we chose each technology
- **How to** run, test, and troubleshoot end-to-end
- **Why** certain design decisions were made

## Table of Contents

1. [What Part 3 is doing (The Big Picture)](#1-what-part-3-is-doing-the-big-picture)
2. [Why each component exists (The Toolchain Explained)](#2-why-each-component-exists-the-toolchain-explained)
3. [Files and responsibilities (Tour of the Project Layout)](#3-files-and-responsibilities-tour-of-the-project-layout)
4. [How the install script works (Deep Dive)](#4-how-the-install-script-works-deep-dive-what-runs-when)
5. [Before running (Pre-Flight Checklist)](#5-before-running-pre-flight-checklist-as-a-senior-would-explain)
6. [How to run everything (Step-by-Step Initiation)](#6-how-to-run-everything-step-by-step-initiation)
7. [How to access services (Testing the Setup)](#7-how-to-access-services-testing-the-setup)
8. [GitOps update demo (Defense Flow)](#8-gitops-update-demo-defense-flow--how-to-prove-it-works)
9. [Verify all required elements (Checklist for Evaluators)](#9-verify-all-required-elements-checklist-for-evaluators)
10. [Common issues and fixes (Diagnostic Guide)](#10-common-issues-and-fixes-diagnostic-guide)
11. [Architecture Overview (How Everything Fits Together)](#11-architecture-overview-how-everything-fits-together)
12. [Key Concepts Glossary (Learn the Lingo)](#12-key-concepts-glossary-learn-the-lingo)
13. [Key Takeaways (What You Should Remember)](#13-key-takeaways-what-you-should-remember)
14. [Further Learning (If You Want to Go Deeper)](#14-further-learning-if-you-want-to-go-deeper)
15. [Quick Reference Commands](#15-quick-reference-commands)

---

## 📌 Bonus: GitLab Integration

After completing Part 3, you can extend your setup with the **Bonus** to replace GitHub with a self-hosted GitLab instance. See `../bonus/README.md` for details.

---

## 1) What Part 3 is doing (The Big Picture)

**The Problem:** In traditional deployments, you SSH into a server, run manual commands, and hope everything works. If your teammates make changes elsewhere, you don't know. Chaos.

**The Solution:** GitOps. Your GitHub repository is the *single source of truth*. A controller (Argo CD) constantly watches that repository. If it notices a difference between "what's in Git" and "what's running in the cluster," it automatically fixes it.

**Part 3 Flow:**
```
You → Edit deployment.yaml → Push to GitHub → Argo CD detects change 
→ Argo CD updates cluster → Application restarts with new version
```

**What actually happens:**
1. K3d creates a lightweight Kubernetes cluster on your machine (using Docker containers as nodes).
2. Argo CD runs inside that cluster.
3. Argo CD periodically fetches your GitHub repo (default: every 3 minutes).
4. If the repo changed, Argo CD updates the cluster automatically.
5. If someone manually changes the cluster, Argo CD reverts it (self-healing).
6. Your app updates without any manual intervention.

---

## 2) Why each component exists (The Toolchain Explained)

Think of it like building a house:
- **Docker** = your building materials and construction site
- **K3d** = a blueprint system that builds the house structure
- **Kubernetes (via K3d)** = the house itself (orchestrates your containers)
- **Argo CD** = a smart property manager (keeps the house matching the blueprint)
- **GitHub** = your master blueprint repository

### Docker
**What it is:** Containerization platform. Packages your app and all its dependencies into a standardized box.
**Why it's here:** K3d runs Kubernetes nodes as Docker containers. So instead of spinning up 3 full Linux VMs (slow, resource-heavy), K3d starts 3 Docker containers that act like Kubernetes nodes. Much faster.
**For you:** You just need Docker installed; K3d handles the rest.

### K3d
**What it is:** A lightweight Kubernetes distribution wrapped in Docker. It's like a "Kubernetes simulator" on your laptop.
**Why it's here:** Full Kubernetes (Google's GKE, AWS EKS) is overkill for local development. K3d gives you 95% of Kubernetes features in 5% of the resource footprint. You can tear it down and recreate it in seconds.
**How it works:** Starts Docker containers running K3s (lightweight Kubernetes), exposes them as a local cluster.
**For you:** `k3d cluster create` → boom, you have a real Kubernetes cluster running locally.

### kubectl
**What it is:** The Kubernetes command-line tool. Your remote control for the cluster.
**Why it's here:** You use it to inspect and manage everything: pods, deployments, services, secrets, logs.
**For you:** Think of it like SSH for Kubernetes. `kubectl get pods` = "show me what containers are running."

### Argo CD
**What it is:** A GitOps controller. Runs **inside** your Kubernetes cluster and continuously watches a GitHub repository.
**Why it's here:** This is the automation engine. Without Argo CD, updating your app means manually running `kubectl apply -f deployment.yaml` every time. With Argo CD, you just `git push` and it happens automatically.
**Key behavior:** 
  - Every 3 minutes, Argo CD fetches your GitHub repo
  - Compares "Git state" vs "Cluster state"
  - If mismatched, updates the cluster to match Git
  - If someone manually edits a pod, Argo CD reverts it (self-healing)
**For you:** Your deployment is now declarative (defined in Git) and automatic.

### Namespaces (argocd & dev)
**What they are:** Virtual clusters within one physical cluster. Isolates resources.
**Why two namespaces:**
  - `argocd` namespace = System infrastructure (the property manager and tools)
  - `dev` namespace = Your application (the tenant/user workload)
**Why separate them:** If a developer accidentally deletes something in `dev`, they don't break Argo CD. Clean separation of concerns.
**For you:** You deploy your app into `dev`; Argo CD lives in `argocd`.

---

## 3) Files and responsibilities (Tour of the Project Layout)

Every file in Part 3 serves a specific purpose. Here's what each one does and why:

### `p3/scripts/install.sh` — The Bootstrap Script
**Purpose:** One-command setup for everything. This is the only file you execute manually.

**What it does (4 steps):**
1. **Install system dependencies** → Docker, curl, certificates (needed for HTTPS)
2. **Install development tools** → kubectl (cluster management), k3d (cluster creation), argocd CLI (Argo CD management)
3. **Create the cluster** → Calls `k3d cluster create iot-cluster` which spins up a Kubernetes cluster
4. **Deploy Argo CD + app** → Installs Argo CD system pods, then tells Argo CD to watch your GitHub repo

**Why this matters:** Without automation, you'd manually download, install, and configure each tool. This script makes Part 3 reproducible in one command. You could share it with a teammate, and they'd get identical setup.

**How it's idempotent:** The script can run multiple times safely. If the cluster already exists, `k3d cluster create` just reuses it. If Argo CD is already installed, `kubectl apply` is idempotent (re-applying same YAML doesn't break anything).

**Special details:**
- Uses `kubectl apply --server-side` to avoid Kubernetes internal annotation limits
- Filters warnings with `grep -v "Warning:"` for clean output
- Uses `|| true` to continue even if a step "fails" (expected failures)

### `p3/confs/namespace.yaml` — Creates the Isolated Environments
**Purpose:** Kubernetes manifests defining two namespaces.

**What it creates:**
```yaml
namespace: argocd   →  System infrastructure lives here
namespace: dev      →  Your app lives here
```

**Why separate namespaces:**
- **Isolation:** If a dev experiment goes wrong, it doesn't affect Argo CD
- **RBAC (Role-Based Access Control):** You could later restrict access (e.g., "developers can modify `dev` but not `argocd`")
- **Clarity:** Clear separation of concerns — anyone looking at the cluster knows where to find what

**When it's applied:** Very first, before anything else. All subsequent components need these namespaces to exist.

### `p3/confs/argocd-app.yaml` — The GitOps Contract
**Purpose:** Tells Argo CD what to watch and how to deploy it.

**What it defines:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application          # This is an Argo CD custom resource
metadata:
  name: playground         # Name of this GitOps-managed app
  namespace: argocd        # Stores in argocd namespace (system level)
spec:
  source:
    repoURL: https://github.com/48d31kh413k/Inception-of-things
    targetRevision: main   # Always watch the 'main' branch
    path: p3/confs/app     # These files are the deployment spec
  
  destination:
    server: https://kubernetes.default.svc
    namespace: dev         # Deploy into 'dev' namespace (user level)
  
  syncPolicy:
    automated:
      prune: true          # Delete cluster resources if removed from Git
      selfHeal: true       # Revert manual cluster changes
    syncOptions:
      - CreateNamespace=true
```

**How it works (the GitOps loop):**
1. Argo CD reads this resource
2. Every 3 minutes, fetches https://github.com/48d31kh413k/Inception-of-things
3. Looks inside `p3/confs/app/` for Kubernetes manifests
4. Compares those manifests to what's running in the `dev` namespace
5. If different, updates the cluster
6. Continuously does this (continuous reconciliation)

**Why each setting:**
- `repoURL`: Points to your public repository. Argo CD must be able to pull it without authentication (use public repos for this exercise)
- `targetRevision: main`: Ensures you're always on the latest main branch. Could also use `v1.0.0` for tags, or specific commit SHAs
- `path: p3/confs/app`: Argo CD doesn't look at the entire repo. It only syncs manifests in this folder
- `automated.prune: true`: If you remove a file from Git, Argo CD removes it from the cluster. Keeps them in sync
- `automated.selfHeal: true`: If a developer manually edits a pod directly (bypassing Argo CD), Argo CD reverts it. Enforces Git as source of truth

**Common mistake:** Forgetting `automated: true`. Without it, you'd need to manually sync every change (GitOps becomes manual).

### `p3/confs/app/deployment.yaml` — The Application Manifests
**Purpose:** Defines what actually runs in the cluster (the payload).

**What it contains (2 Kubernetes resources):**

**Resource 1: Deployment**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: playground
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: playground
  template:
    metadata:
      labels:
        app: playground
    spec:
      containers:
      - name: app
        image: wil42/playground:v1  # ← THIS is what you change for v1→v2
        ports:
        - containerPort: 8888
```

**What it does:** Tells Kubernetes: "Run 1 copy of `wil42/playground:v1` on port 8888."

**Why this design:** 
- `replicas: 1` = one pod (one container instance). Could be 3, 10, 100 for production scaling
- `image: wil42/playground:v1` = Docker image and version. When you change this to `v2` and push Git, Argo CD redeploys automatically
- `containerPort: 8888` = the port inside the container. You'll port-forward to this

**Resource 2: Service**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: playground
  namespace: dev
spec:
  type: LoadBalancer
  selector:
    app: playground
  ports:
  - port: 8888
    targetPort: 8888
```

**What it does:** Creates a stable DNS name (`playground.dev.svc.cluster.local`) pointing to your deployment's pods.

**Why you need it:**
- Pod IPs are ephemeral (change if pod restarts)
- Service name is stable. You port-forward to the Service, not individual pods
- Think of it like a load balancer with a stable name: multiple pods can be behind one Service

**How they work together:**
1. Deployment creates 1 pod running the app
2. Service creates a DNS entry that routes to that pod
3. Port-forward to the Service: `kubectl port-forward svc/playground -n dev 8888:8888`
4. Now `curl localhost:8888/` reaches the pod inside the cluster

**The v1 ↔ v2 demo:**
- Current: `image: wil42/playground:v1`
- To update: Change to `image: wil42/playground:v2`
- Push to GitHub
- Argo CD detects change → triggers new deployment
- K8s rolls out new pod(s) with v2 running

---

## 4) How the install script works (Deep Dive: What Runs When)

When you run `./scripts/install.sh`, here's exactly what happens, step by step:

### Quick Overview (The Flow)
```
Dependencies installed?
    ↓ Yes
Is Docker running?
    ↓ Yes
Is kubectl installed?
    ↓ Yes
Do we have k3d?
    ↓ Yes
Create cluster named 'iot-cluster'
    ↓ (or reuse if exists)
Create namespaces (argocd, dev)
    ↓
Install Argo CD system pods
    ↓
Wait for argocd-server to be ready (30 sec max)
    ↓
Apply the Application manifest (argocd-app.yaml)
    ↓
Print success + admin credentials
```

### Detailed Breakdown

**Step 1: Install System Dependencies**
```bash
# What: Installs basic packages
apt-get update && apt-get install -y docker.io curl ca-certificates

# Why: 
# - docker.io = Docker daemon (needed for k3d)
# - curl = HTTP requests (needed to download tools)
# - ca-certificates = trusted certificate chain (HTTPS validation)
```

**Step 2: Enable and Start Docker**
```bash
# What:
systemctl enable docker
systemctl start docker
usermod -aG docker $USER

# Why:
# - enable = start Docker automatically on reboot
# - start = start Docker now
# - usermod = add current user to 'docker' group (lets you run docker without sudo)
# - After this, open a new shell or run `newgrp docker` to apply permissions
```

**Step 3: Install kubectl**
```bash
# What: Downloads and installs kubectl binary
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Why:
# - kubectl is how you talk to Kubernetes
# - "stable.txt" = latest stable version (e.g., v1.29.0)
# - /usr/local/bin = adds to $PATH so `kubectl` is available from anywhere
```

**Step 4: Install k3d**
```bash
# What: Downloads and installs k3d for cluster creation
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Why:
# - k3d is how you create a local Kubernetes cluster
# - Uses the official install script (trust the source)
# - k3d is a wrapper around k3s (lightweight Kubernetes)
```

**Step 5: Install Argo CD CLI**
```bash
# What: Downloads argocd command-line tool
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/v3.3.3/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# Why:
# - argocd CLI lets you inspect and manage Argo CD from terminal
# - v3.3.3 = specific tested version (pinned, not random version)
# - chmod +x = marks it as executable
```

**Step 6: Create the K3d Cluster**
```bash
# What:
k3d cluster create iot-cluster \
  -p "8888:8888@loadbalancer" \
  --wait

# Why:
# - iot-cluster = cluster name (matches project)
# - -p "8888:8888@loadbalancer" = host port 8888 → cluster load balancer port 8888
#   This lets you access apps inside the cluster from your machine
# - --wait = wait for cluster to be ready before script continues

# What actually happens under the hood:
# 1. K3d pulls k3s Docker image
# 2. Starts Docker containers running k3s nodes (1 control plane, 2 workers)
# 3. Sets up internal networking
# 4. Exposes port 8888 on your machine pointing to the load balancer
# 5. Generates kubeconfig file (~/.kube/config) so kubectl knows how to reach it
```

**Step 7: Create Namespaces**
```bash
# What: Applies namespace.yaml to create 'argocd' and 'dev' namespaces
kubectl apply -f confs/namespace.yaml

# Why:
# - Must be done before anything else
# - Subsequent resources need these namespaces to exist
# - kubectl apply is idempotent (safe to run multiple times)
```

**Step 8: Install Argo CD**
```bash
# What: Applies official Argo CD manifests
kubectl apply --server-side \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  -n argocd \
  2>&1 | grep -v "Warning:" || true

# Why:
# - --server-side = use server-side apply (avoids Kubernetes annotation overflow bugs)
# - -n argocd = deploy in argocd namespace
# - Official manifests = 100+ resources (pods, services, secrets, CRDs, RBAC rules)
# - 2>&1 | grep -v "Warning:" = suppress non-critical warnings
# - || true = continue even if this "fails" (expected minor issues)

# What gets created:
# - argocd-server Pod → Argo CD web UI
# - argocd-repo-server Pod → fetches manifests from Git
# - argocd-application-controller Pod → continuously reconciles
# - Plus: RBAC roles, ServiceAccounts, Secrets, ConfigMaps
```

**Step 9: Wait for Argo CD Server**
```bash
# What: Waits until argocd-server pod is healthy
kubectl rollout status -n argocd deployment/argocd-server --timeout=5m

# Why:
# - Ensures Argo CD UI is ready before we register the first app
# - 5m timeout = wait up to 5 minutes
# - If server isn't ready by then, something went wrong (usually image pull issue)
```

**Step 10: Apply the Application**
```bash
# What: Registers the app with Argo CD
kubectl apply -f confs/argocd-app.yaml

# Why:
# - This tells Argo CD: "Watch GitHub for changes in p3/confs/app"
# - Without this, Argo CD exists but doesn't manage anything
# - Now Argo CD starts its 3-minute polling loop
```

**Step 11: Print Credentials**
```bash
# What: Shows you how to access everything
echo "Argo CD Admin Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
echo "Port-forward Argo CD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "Port-forward App: kubectl port-forward svc/playground -n dev 8888:8888"

# Why: You need this info to test everything
```

### Idempotency (Can You Run It Twice?)
**YES!** The script is idempotent. You can run it multiple times:
- K3d cluster already exists? Reuses it.
- Namespaces already exist? Kubectl apply is idempotent.
- Argo CD already installed? Re-applying manifests doesn't break anything.

**Exception:** If something fails mid-way, check error messages. Most errors are:
- Docker not running → `sudo systemctl start docker`
- Docker permission denied → `newgrp docker` then rerun
- Port 8888 already in use → kill the existing process or use different port

---

## 5) Before running (Pre-Flight Checklist)

Before you run the install script, an experienced engineer would check these things. Here's why:

### 1. Verify Your GitHub Repo Is Public
**Check:**
```bash
cat confs/argocd-app.yaml | grep repoURL
```

Expected output:
```
    repoURL: https://github.com/48d31kh413k/Inception-of-things
```

**Why:** Argo CD fetches manifests from this URL without authentication (public access only). If the repo is private, Argo CD gets `403 Forbidden` and sync fails.

**What to do if it's private:** 
- Make the repo public for this exercise, OR
- Configure SSH keys in Argo CD (more complex, beyond scope here)

### 2. Verify the path points to the right folder
**Check:**
```bash
cat confs/argocd-app.yaml | grep "path:"
```

Expected output:
```
    path: p3/confs/app
```

**Why:** Argo CD only looks in this folder for manifests. If you point to the wrong path, no deployments happen.

**What to do if wrong:**
```bash
sed -i 's|path: p3/confs/app|path: correct/path|g' confs/argocd-app.yaml
```

### 3. Verify your app image is publicly available
**Check:**
```bash
cat confs/app/deployment.yaml | grep image
```

Expected output:
```
        image: wil42/playground:v1
```

**Why:** Docker image must be publicly available on Docker Hub. When the pod starts, K3s pulls this image. If it doesn't exist or is private (403), pod gets `ImagePullBackOff` status.

**How to test:**
```bash
docker pull wil42/playground:v1
```

If this succeeds, you're good. If it fails, image doesn't exist or is private.

### 4. Check that Docker is installed and running (macOS/Linux)
**Run:**
```bash
docker ps
```

**Expected:** Shows running containers (or empty list if no containers).

**If error:** Docker daemon isn't running.
```bash
# macOS
open /Applications/Docker.app

# Linux
sudo systemctl start docker
```

### 5. Ensure no services already using ports 8888, 8080
**Why:** The script tries to bind these ports. If they're in use, cluster creation fails.

**Check:**
```bash
# macOS
lsof -i :8888
lsof -i :8080

# Linux
sudo ss -tlnp | grep ':8888'
sudo ss -tlnp | grep ':8080'
```

**If ports are in use:** 
- Kill the existing process, OR
- Modify the script to use different ports (advanced)

### 6. Verify you have internet and can reach GitHub/Docker Hub
**Quick test:**
```bash
curl -I https://github.com
curl -I https://hub.docker.com
```

**Why:** Script downloads tools and container images. No internet = script hangs.

### 7. Check available disk space (K3d is lightweight but still needs space)
**Run:**
```bash
df -h
```

**Need:** At least 5GB free on your root partition.

### Checklist Template
Print this out mentally before running:
```
□ GitHub repo is public
□ argocd-app.yaml points to correct path
□ Docker image wil42/playground:v1 is public
□ Docker daemon is running
□ Ports 8888 and 8080 are free
□ Internet connection works
□ At least 5GB disk space available
□ I'm in the p3 directory
```

---

## 6) How to run everything (Step-by-Step Initiation)

**Time to completion:** ~3 minutes on first run, ~30 seconds on repeat runs

### Step 0: Open Terminal, Navigate to p3
```bash
cd /path/to/Inception-of-things/p3
pwd  # Verify you're in the right place (should end with /p3)
```

### Step 1: Make the Script Executable
The script file exists but needs execute permission:
```bash
chmod +x scripts/install.sh
```

**What this does:** Marks the shell script as executable. Without this, you'd get "Permission denied."

### Step 2: Run the Bootstrap Script
```bash
./scripts/install.sh
```

**What to expect:**
- First 30 seconds: Package manager updates (apt-get), downloads tools
- Next 60 seconds: Docker builds k3d cluster (pulling k3s image, starting nodes)
- Another 30 seconds: Argo CD deployment (pulling Argo CD images, starting pods)
- Final output: Argo CD admin password, port-forward commands

**Don't worry about these messages:**
- "Package lists... already the newest version" = package already installed, skipped
- "warning:" from Kubernetes = normal metadata warnings, script filters them
- "resource already exists" = idempotent re-run, manifests already applied

**You'll know it worked when you see:**
```
✓ Argo CD deployed successfully
Admin password: {long-string}
Access Argo CD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443
Access App: kubectl port-forward svc/playground -n dev 8888:8888
```

### Step 3: Handle Docker Group Permissions (if needed)
If you get "Cannot connect to Docker daemon," the user doesn't have permission.

**Option A (permanent, recommended):**
```bash
newgrp docker  # Switch to docker group for current shell session
# Now rerun the script
./scripts/install.sh
```

**Option B (permanent, one-time setup):**
```bash
# Already did usermod in script, but permissions take effect on next login
# Logout and login, then rerun script
```

### Step 4: Verify Everything Started
After script completes successfully:

```bash
# Check cluster exists
k3d cluster list

# Check namespaces created
kubectl get ns

# Check Argo CD pods running
kubectl get pods -n argocd

# Check app deployed in dev namespace
kubectl get pods -n dev

# Check Argo CD Application registered
kubectl get applications -n argocd
```

**Expected output summary:**
```
CLUSTER        STATUS     SERVERS   AGENTS
iot-cluster    running    1         2

NAME              STATUS   AGE
argocd            Active   2m
dev               Active   2m
kube-system       Active   2m
kube-public       Active   2m

NAME                               READY   STATUS    RESTARTS   AGE
argocd-server-6d8f5f...           1/1     Running   0          2m
argocd-repo-server-...             1/1     Running   0          2m
argocd-application-controller-...  1/1     Running   0          2m

NAME                    READY   STATUS    RESTARTS   AGE
playground-6d8f5f...   1/1     Running   0          2m

NAME           SYNC STATUS   HEALTH STATUS
playground     Synced        Healthy
```

**What these statuses mean:**
- `Synced` = Git state matches Cluster state (good!)
- `Healthy` = All pods in deployment are running
- If you see `Unknown` or `OutOfSync`, something didn't work (debug in section 10)

---

## 7) How to access services (Testing the Setup)

Once the script completes, your cluster is running inside Docker containers on your machine. To access services, you need port-forwarding.

**Why port-forwarding?** Services run *inside* the cluster's private network. Your machine can't directly access `localhost:8080` because Argo CD is listening inside a Docker container. `kubectl port-forward` creates a tunnel: `localhost:8080` → Docker network → Argo CD pod.

### Argo CD Web UI

**Step 1: Start port-forward**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

**What this does:**
- Listens on your machine's `localhost:8080`
- Any traffic there goes to the argocd-server Service on port 443 (HTTPS inside cluster)
- Terminal will show: `Forwarding from 127.0.0.1:8080 -> 8443`
- Leave this running (don't Ctrl+C)

**Why port 443 (HTTPS)?** Argo CD uses TLS for secure communication. The Service redirects from 443 to the pod's HTTPS port.

**Step 2: Open browser**
```
https://localhost:8080
```

**Warning:** Browser shows certificate warning (self-signed). That's expected for local dev. Click "Advanced" → "Proceed anyway."

**Step 3: Login**
```
Username: admin
Password: [copied from script output]
```

**Retrieve password if you lost it:**
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo
```

**What you'll see:**
- Applications page: Shows `playground` app
- Status: `Synced` (green), `Healthy` (green)
- Sync Policy: `Automatic` enabled
- Last Sync: Recent timestamp

### Application Web Service

**Step 1: Start port-forward (in another terminal)**
```bash
kubectl port-forward svc/playground -n dev 8888:8888
```

**What this does:**
- Listens on `localhost:8888`
- Routes to the playground Service in `dev` namespace
- Terminal shows: `Forwarding from 127.0.0.1:8888 -> 8888`

**Step 2: Test the app**
```bash
curl http://localhost:8888/
```

**Expected output:**
```
Version: v1  ← current deployed version
```

Or visit `http://localhost:8888/` in browser.

### Checking Logs (Debugging Port-Forward Issues)

**Port-forward connected but app unreachable:**
```bash
# Check pod is actually running
kubectl get pods -n dev

# Check pod logs
kubectl logs -n dev deployment/playground

# Describe pod to see errors
kubectl describe pod -n dev -l app=playground
```

**Port says "already in use":**
```bash
# Find what's using the port
lsof -i :8888

# Kill it, OR use different local port
kubectl port-forward svc/playground -n dev 9999:8888  # Local 9999 → cluster 8888
```

### Terminal-Free Access (Optional Advanced)

If you want both port-forwards running without occupying terminals:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
kubectl port-forward svc/playground -n dev 8888:8888 &

# List background jobs
jobs

# Kill specific job later
kill %1  # kills first job
```

---

## 8) GitOps update demo (Defense Flow - How to Prove It Works)

This is the core demonstration for evaluation. You'll show how GitOps automation works.

**Objective:** Change the app from v1 to v2 via Git, and Argo CD automatically updates the cluster.

**What actually happens:**
1. You edit a file locally (v1 → v2)
2. Commit and push to GitHub
3. Argo CD fetches GitHub every 3 minutes, detects the change
4. Argo CD updates the Kubernetes cluster automatically
5. New pod comes up with v2, old pod terminates
6. You curl the endpoint and get v2 response

### The Full Flow (Step by Step)

**Step 1: Verify current version (v1)**
```bash
# Check what's currently deployed
kubectl describe deployment -n dev playground | grep -i image

# Output should show:
# Image: wil42/playground:v1
```

##### SCREENSHOT NEEDED HERE ###
# **Show:** Deployment showing v1 image

**Also test the endpoint:**
```bash
curl http://localhost:8888/
# Output: Version: v1
```

##### SCREENSHOT NEEDED HERE ###
# **Show:** curl response showing v1

**Step 2: Edit the deployment file locally**
```bash
# Option A: Use sed (one-liner)
sed -i '' 's/wil42\/playground:v1/wil42\/playground:v2/g' confs/app/deployment.yaml

# Option B: Manual edit (learn what changes)
open confs/app/deployment.yaml  # macOS
# or
nano confs/app/deployment.yaml  # Linux
# Find the line: image: wil42/playground:v1
# Change it to: image: wil42/playground:v2
# Save and exit
```

**Verify the change locally:**
```bash
cat confs/app/deployment.yaml | grep image
# Should output: image: wil42/playground:v2
```

**Step 3: Commit the change**
```bash
git add confs/app/deployment.yaml
git commit -m "chore(p3): switch playground image from v1 to v2"

# Output shows: 1 file changed, 1 insertion(+), 1 deletion(-)
```

##### SCREENSHOT NEEDED HERE ###
# **Show:** Git commit and the push output to GitHub

**Push to GitHub:**
```bash
git push origin main
```

**Step 4: Watch Argo CD detect and sync the change**
```bash
# Monitor the application in Argo CD
kubectl get application -n argocd

# Watch the status change from Synced to OutOfSync to Synced again
```

##### SCREENSHOT NEEDED HERE ###
# **Show:** Argo CD dashboard showing the application going OutOfSync then back to Synced

**Step 5: Verify new version is deployed**
```bash
# Check the image tag has changed
kubectl describe deployment -n dev playground | grep -i image
# Should show: image: wil42/playground:v2
```

##### SCREENSHOT NEEDED HERE ###
# **Show:** Deployment showing v2 image

**Why commit?** Git tracks changes. Argo CD reads Git commits. Uncommitted changes aren't tracked.

**Step 6: Verify the app is running v2**
```bash
curl http://localhost:8888/
# Output should now show: Version: v2
```

##### SCREENSHOT NEEDED HERE ###
# **Show:** curl response showing v2 (final proof that GitOps worked!)
```bash
git push origin main
```

**What happens inside GitHub:**
- Your commit goes to https://github.com/48d31kh413k/Inception-of-things
- The `main` branch now includes v2 image tag
- All changes pushed to remote (Argo CD can see them)

**Verify it pushed:**
```bash
git log -1 --oneline  # Shows your commit hash
git remote -v         # Shows upstream URL
```

**Step 5: Trigger immediate sync (manual refresh)**

By default, Argo CD polls GitHub every 3 minutes. For demo purposes, trigger immediate sync:
```bash
kubectl annotate application playground -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite
```

**What this does:**
- Annotates the Argo CD Application resource with a "refresh" marker
- Argo CD controller sees this annotation and syncs **immediately** (not waiting 3 minutes)
- Then removes the annotation
- This is safe and idempotent (can run multiple times)

**Why 3-minute default?** Polling every second would hammer GitHub API and waste resources. 3 minutes is a good balance for production. For development/demos, manual refresh bridges the gap.

**Step 6: Monitor the rollout**

Watch pods terminate and new ones start:
```bash
# Open two terminals
# Terminal 1: Watch pods update in real-time
kubectl get pods -n dev -w

# Terminal 2: Wait for deployment to complete
kubectl rollout status deployment/playground -n dev --timeout=2m
```

**What you'll see:**
```
playground-OLD-HASH      1/1   Running       0    5m
playground-NEW-HASH      0/1   Pending       0    1s
playground-OLD-HASH      1/1   Terminating   0    8s
playground-NEW-HASH      1/1   Running       0    3s
playground-OLD-HASH      0/1   Terminated    0    10s
```

**What's happening:**
- K8s starts a new pod with v2 image
- Once new pod is healthy, kills old pod
- This is a "rolling update" (zero downtime)

**Step 7: Verify new version**

```bash
# Check deployment spec
kubectl describe deployment -n dev playground | grep -i image
# Output: Image: wil42/playground:v2

# Test the endpoint
curl http://localhost:8888/
# Output: Version: v2
```

**Argo CD UI:**
- Open https://localhost:8080 (with port-forward still running)
- Click on `playground` application
- See sync time updated to "just now"
- See all resources healthy/synced

### Switching Back (v2 → v1)

Same flow:
```bash
# Edit back to v1
sed -i '' 's/wil42\/playground:v2/wil42\/playground:v1/g' confs/app/deployment.yaml

# Commit & push
git add confs/app/deployment.yaml
git commit -m "chore(p3): revert playground image back to v1"
git push

# Manual refresh
kubectl annotate application playground -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite

# Verify
kubectl get pods -n dev -w  # Watch rollout
curl http://localhost:8888/  # Should say v1 again
```

### What This Demonstrates (For Evaluators)

✓ **GitOps workflow:** Source of truth is Git, not manual commands  
✓ **Automatic synchronization:** No `kubectl apply` needed  
✓ **Continuous reconciliation:** Cluster always matches Git  
✓ **Idempotent operations:** Can re-apply same manifests safely  
✓ **Multi-version support:** Can change versions without downtime (rolling updates)  
✓ **Audit trail:** All changes tracked in Git history

---

## 9) Verify all required elements (Checklist for Evaluators)

Run these commands to prove all components are working:

### Namespaces (Isolation)
```bash
kubectl get namespaces
# Expected: argocd, dev, kube-system, kube-public, kube-node-lease
```

### Argo CD System Components
```bash
kubectl get pods -n argocd
# Expected: argocd-server, argocd-repo-server, argocd-application-controller all Running
```

### Application Pods
```bash
kubectl get pods -n dev
# Expected: One pod named playground-{HASH} in Running status
```

### Application Manifest (Deployment + Service)
```bash
kubectl get all -n dev
# Expected:
#   deployment.apps/playground
#   service/playground
#   pod/playground-{HASH}
```

### Argo CD Application Resource (the GitOps contract)
```bash
kubectl get applications -n argocd
# Expected: application.argoproj.io/playground

# Detailed status:
kubectl describe application playground -n argocd
# Expected output includes:
#   Sync Status: Synced (green)
#   Health Status: Healthy (green)
#   Repo: https://github.com/48d31kh413k/Inception-of-things
#   Path: p3/confs/app
#   Dest Namespace: dev
```

### Verify Auto-Sync Policy
```bash
kubectl get application playground -n argocd -o yaml | grep -A 10 "syncPolicy"
# Expected: automated: true, prune: true, selfHeal: true
```

### Verify Deployed Image Tag
```bash
kubectl get deployment -n dev playground -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: wil42/playground:v1 (or v2 if you ran the demo)
```

### End-to-End: Trace the GitOps Loop

**1. Check what Argo CD read from GitHub:**
```bash
kubectl describe application playground -n argocd | grep -i "repo"
# Shows: Repository source and current revision being tracked
```

**2. Check what Argo CD applied to cluster:**
```bash
kubectl get deployment -n dev -o yaml | head -30
# Should match confs/app/deployment.yaml from GitHub
```

**3. Verify sync is automatic (not manual):**
```bash
# Make a Git change, push it
sed -i '' 's/v1/v2/g' confs/app/deployment.yaml
git add . && git commit -m "test" && git push

# Refresh Argo CD to see the new state
kubectl annotate application playground -n argocd argocd.argoproj.io/refresh=hard --overwrite

# Check it synced without you typing kubectl apply
kubectl get pods -n dev  # Should show new pods with v2
```

### Quick Health Check (Single Command)
```bash
echo "=== Cluster Status ===" && \
k3d cluster list && \
echo "=== Namespaces ===" && \
kubectl get ns && \
echo "=== Argo CD ===" && \
kubectl get pods -n argocd && \
echo "=== Application ===" && \
kubectl get all -n dev && \
echo "=== GitOps Contract ===" && \
kubectl get application -n argocd && \
echo "=== All checks passed! ==="
```

---

## 10) Common issues and fixes (Diagnostic Guide)

When something doesn't work, here's how an experienced engineer debugs it:

### Issue 1: Argo CD Application is `OutOfSync` or `Unknown`

**Symptoms:**
```bash
kubectl get application -n argocd
# Output: playground   Unknown
# or: playground   OutOfSync
```

**Root causes:** Argo CD can't connect to GitHub, wrong path, or wrong repo URL.

**Debug steps:**

**Step 1: Check Argo CD logs**
```bash
# Check repo-server logs (fetches manifests from GitHub)
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server --tail=50

# Check application-controller logs (syncs cluster)
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=50
```

**Common log errors:**
- `"repository not found"` = repo URL is wrong or private
- `"no such file or directory"` = path in argocd-app.yaml is wrong
- `"timeout"` = network issue, can't reach GitHub

**Step 2: Verify Application manifest**
```bash
kubectl get application playground -n argocd -o yaml

# Check these fields:
# spec.source.repoURL          ← should be your GitHub repo
# spec.source.path             ← should be p3/confs/app
# spec.source.targetRevision   ← should be main or specific branch
# spec.destination.namespace   ← should be dev
```

**Step 3: Manually check if manifests exist on GitHub**
```bash
# Replace with your actual repo URL
curl -s https://raw.githubusercontent.com/48d31kh413k/Inception-of-things/main/p3/confs/app/deployment.yaml | head -20

# If you get 404, the path is wrong
# If you get 403, the repo is private
```

**Fix:**
```bash
# Edit the Application manifest
kubectl edit application playground -n argocd

# Fix the repoURL or path, save and exit
# Argo CD will immediately retry
kubectl get application playground -n argocd
# Should now show Synced or Healthy
```

### Issue 2: Pod has `ImagePullBackOff` status

**Symptoms:**
```bash
kubectl get pods -n dev
# Output: playground-{HASH}   0/1   ImagePullBackOff
```

**Root cause:** Docker image doesn't exist, is private, or tag is wrong.

**Debug:**
```bash
# Check the pod details
kubectl describe pod -n dev -l app=playground

# Look for event like:
# "Failed to pull image "wil42/playground:v1": rpc error: code = Unknown desc = Error response from daemon..."

# Try pulling the image yourself (simulates what pod tries)
docker pull wil42/playground:v1  # Should succeed if image is available

# Check the image name in deployment
kubectl get deployment -n dev -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**Fix:**
```bash
# Update deployment with correct image
kubectl set image deployment/playground -n dev app=wil42/playground:v1

# Or edit the file and push to Git
sed -i '' 's|image: .*|image: wil42/playground:v1|g' confs/app/deployment.yaml
git add . && git commit -m "fix: correct image" && git push
kubectl annotate application playground -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

### Issue 3: Cannot connect to Docker daemon

**Symptoms:**
```bash
./scripts/install.sh
# Error: Cannot connect to Docker daemon at unix:///var/run/docker.sock
```

**Root causes:** Docker isn't running, or user doesn't have permission.

**Debug:**
```bash
# Is Docker running?
docker ps
# If fails: daemon not running

# Do you have permission?
# If error "permission denied", user not in docker group
```

**Fix (Option A: Switch group temporarily):**
```bash
newgrp docker
# Now try the script again
./scripts/install.sh
```

**Fix (Option B: Restart Docker service):**
```bash
# macOS
open /Applications/Docker.app

# Linux
sudo systemctl restart docker
sudo usermod -aG docker $USER
# Then logout and login
```

### Issue 4: Port already in use (8888 or 8080)

**Symptoms:**
```bash
./scripts/install.sh
# Error: address already in use
```

**Debug:**
```bash
# What's using the port?
lsof -i :8888  # or :8080
```

**Fix (Option A: Kill existing process):**
```bash
# macOS/Linux
lsof -i :8888 -t | xargs kill -9

# Then rerun script
./scripts/install.sh
```

**Fix (Option B: Use different port):**
```bash
# Edit the k3d cluster creation line in install.sh
# Change: -p "8888:8888@loadbalancer"
# To:     -p "9999:8888@loadbalancer"  (local 9999 → cluster 8888)

# Then access app at: localhost:9999 instead of 8888
```

### Issue 5: Argo CD Server Pod won't start (Pending or CrashLoopBackOff)

**Symptoms:**
```bash
kubectl get pods -n argocd
# argocd-server-{HASH}   0/1   CrashLoopBackOff
```

**Debug:**
```bash
# Check pod status
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server

# Check pod logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=50

# Look for errors like:
# - ImagePullBackOff = image can't be pulled (network/private)
# - Pending = no resources (cluster full)
# - CrashLoopBackOff = pod keeps crashing (check logs)
```

**Fix: Increase timeout and retry**
```bash
# Script has 5-minute wait. If longer needed:
kubectl rollout status deployment/argocd-server -n argocd --timeout=10m

# If that fails, delete and reapply
kubectl delete deployment argocd-server -n argocd
kubectl apply --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml -n argocd
```

### Issue 6: Application status shows `Synced` but pods don't match Git

**Symptoms:**
- Argo CD says everything is synced
- But `kubectl describe deployment` shows different image than Git

**Root cause:** You edited files locally but didn't push to Git. Argo CD only sees Git state, not local state.

**Debug:**
```bash
# Check local file
cat confs/app/deployment.yaml | grep image

# Check what's in GitHub (what Argo CD sees)
curl -s https://raw.githubusercontent.com/48d31kh413k/Inception-of-things/main/p3/confs/app/deployment.yaml | grep image

# Are they the same?
```

**Fix:**
```bash
# Commit and push your local changes
git status  # Shows what's uncommitted
git add confs/app/deployment.yaml
git commit -m "update: image version"
git push

# Trigger sync
kubectl annotate application playground -n argocd argocd.argoproj.io/refresh=hard --overwrite

# Verify
kubectl get pods -n dev  # Should show new pods with new image
```

### Issue 7: Script hangs or times out

**Symptoms:**
```bash
./scripts/install.sh
# Hangs for 5+ minutes, then fails or times out
```

**Causes:** Network issues, Docker image pull timeout, or Kubernetes API issues.

**Debug:**
```bash
# Check if K3d cluster is running
k3d cluster list

# Check if kubectl can reach cluster
kubectl get nodes

# Check internet connectivity
curl -I https://github.com
```

**Fix:**
```bash
# Kill the script (Ctrl+C)

# Verify Docker is accessible
docker ps

# Rerun script (it's idempotent)
./scripts/install.sh

# If still fails, clean up and restart
k3d cluster delete iot-cluster
./scripts/install.sh
```

### The Nuclear Option: Clean Up and Start Fresh

If everything is broken, start completely over:

```bash
# Stop any port-forwards (Ctrl+C if running)

# Delete the cluster
k3d cluster delete iot-cluster  # Takes ~10 seconds

# Verify it's gone
k3d cluster list  # Should be empty

# Clear kubeconfig of that cluster
kubectl config delete-context k3d-iot-cluster 2>/dev/null || true
kubectl config delete-cluster k3d-iot-cluster 2>/dev/null || true

# Rerun the install script
cd p3
./scripts/install.sh
```

### When to Ask for Help (Red Flags)

If you see these, something is fundamentally wrong:
- `Cannot connect to Docker daemon` (after restarting Docker) = Docker issue, not Part 3
- `kubectl: not found` = kubectl installation failed, system issue
- `Network timeout` repeatedly = internet or firewall issue
- Pod stuck in `Pending` for 10+ minutes = cluster resource issue

These indicate system-level problems, not Part 3 configuration issues.

---

## 11) Architecture Overview (How Everything Fits Together)

```
Your Machine (macOS/Linux)
┌─────────────────────────────────────────────────────┐
│                                                     │
│  ┌───────────────┐         ┌──────────────────┐   │
│  │ Your Terminal │         │ Docker Desktop   │   │
│  └───────┬───────┘         │ (Docker daemon)  │   │
│          │                 └────────┬─────────┘   │
│          │                          │             │
│          └──────────────┬───────────┘             │
│                         │                         │
│                   [runs inside]                   │
│                         │                         │
└─────────────────────────┼─────────────────────────┘
                          │
            ┌─────────────┴──────────────┐
            │                            │
          [Docker Container 1]      [Docker Container 2]  ... (Worker nodes)
            (K3s Master)                (K3s Worker)
            
            Inside these containers: Complete Kubernetes cluster!
            
            ┌──────────────────────────────────────────────┐
            │         K3d Kubernetes Cluster               │
            │                                              │
            │  ┌──────────────────┐  ┌──────────────────┐ │
            │  │ argocd namespace │  │  dev namespace   │ │
            │  │                  │  │                  │ │
            │  │ ┌──────────────┐ │  │ ┌──────────────┐ │ │
            │  │ │ argocd-server├──┐ │ │ playground   │ │ │
            │  │ │ (UI on 8443) │ │ │ │ pod (v1→v2)  │ │ │
            │  │ └──────────────┘ │ │ │ ├──────────────┤ │ │
            │  │ ┌──────────────┐ │ │ │ │ Port 8888    │ │ │
            │  │ │ repo-server  │ │ │ │ └──────────────┘ │ │
            │  │ │ (fetches Git)├─┼─┘ ┌──────────────┐ │ │
            │  │ └──────────────┘ │   │ Service      │ │ │
            │  │ ┌──────────────┐ │   │ (stable DNS) │ │ │
            │  │ │ app-ctrl     │ │   └──────────────┘ │ │
            │  │ │ (syncs)      │ │                    │ │
            │  │ └──────────────┘ │                    │ │
            │  └──────────────────┘                    │ │
            │                  ▲                        │ │
            │                  │                        │ │
            │           [syncs this]                    │ │
            │                  │                        │ │
            │         ┌────────┴────────┐              │ │
            │         │                 │              │ │
            │  ┌──────────────┐  ┌─────────────────┐  │ │
            │  │ Application  │  │ Deployment      │  │ │
            │  │ Resource     │  │ (what Argo CD   │  │ │
            │  │ (GitOps      │  │  applies to     │  │ │
            │  │  contract)   │  │  cluster)       │  │ │
            │  └──────────────┘  └─────────────────┘  │ │
            │        ▲                                  │ │
            │        │                                  │ │
            │  [defines this]                           │ │
            └────────┼──────────────────────────────────┘
                     │
                     │  Argo CD watches GitHub
                     │  (every 3 minutes)
                     │
            ┌────────┴────────────────────────────┐
            │                                     │
            │    GitHub Repository                │
            │                                     │
            │    p3/confs/app/deployment.yaml     │
            │    - Deployment: pod spec           │
            │    - Service: networking            │
            │                                     │
            │    p3/confs/argocd-app.yaml         │
            │    - GitOps contract                │
            │    - Auto-sync enabled              │
            └─────────────────────────────────────┘
```

**Data Flow (What Happens When You Push):**

```
1. You edit deployment.yaml (v1 → v2)
   ↓
2. You git commit + git push
   ↓
3. GitHub updates main branch
   ↓
4. Argo CD repo-server polls every 3 minutes
   ↓
5. repo-server sees change: v2 instead of v1
   ↓
6. application-controller compares: Git (v2) vs Cluster (v1)
   ↓
7. Mismatch detected → sync needed
   ↓
8. Argo CD calls Kubernetes API: "Update Deployment to v2"
   ↓
9. Kubernetes: Starts new pod (v2), kills old pod (v1)
   ↓
10. You curl localhost:8888 → get v2 response
```

---

## 12) Key Concepts Glossary (Learn the Lingo)

### GitOps
**Definition:** Practice of declaring infrastructure/app state in Git, using a controller to keep reality synchronized with Git.
**In Part 3:** Argo CD watches your Git repo and updates the cluster.
**Key benefit:** "Source of truth" is Git, not manual kubectl commands.

### GitOps Controller (Argo CD)
**Definition:** Software that runs inside cluster and continuously reconciles cluster state with Git state.
**Job:** Every N seconds, fetch Git → compare to cluster → fix differences.
**In Part 3:** Argo CD is the controller that updates your app when you push.

### Reconciliation Loop
**Definition:** Continuous process of comparing desired state (Git) to actual state (cluster), then fixing differences.
**In Part 3:** Argo CD does this every 3 minutes by default.
**Why it matters:** Automatic self-healing. If pod dies, new one replaces it. If someone manually deletes a pod, it recreates.

### Kubernetes Manifest
**Definition:** YAML file describing what you want Kubernetes to create (pods, services, deployments, etc.).
**In Part 3:** `confs/app/deployment.yaml` and `confs/argocd-app.yaml` are manifests.
**Key idea:** Declarative, not imperative. You say "I want 2 replicas of app:v1," Kubernetes figures out how to achieve it.

### Deployment
**Definition:** Kubernetes resource that manages pod replicas, handles scaling and updates.
**In Part 3:** `deployment.yaml` tells Kubernetes to run 1 replica of `wil42/playground`.
**Rolling Update:** When you change image tag, Kubernetes starts new pod, verifies it's healthy, then kills old pod. Zero downtime.

### Service
**Definition:** Stable DNS name and load balancer for accessing pods inside cluster.
**Problem it solves:** Pod IPs change when they restart. Service name (`playground.dev.svc.cluster.local`) never changes.
**In Part 3:** Service named `playground` routes to pods matched by selector `app=playground`.

### Namespace
**Definition:** Virtual cluster within physical cluster. Isolates resources.
**In Part 3:** `argocd` namespace = system, `dev` namespace = your app.
**Why it matters:** Developers can't accidentally delete Argo CD by deleting everything in `dev`.

### Port-Forward
**Definition:** Tunnel from your machine port to a pod/service inside the cluster.
**In Part 3:** `kubectl port-forward svc/playground -n dev 8888:8888` = local 8888 → cluster 8888.
**Why needed:** Services run inside cluster's private network. Port-forward bridges to your machine.

### Sync/Out-of-Sync
**Sync Status Meanings:**
- **Synced:** Cluster state matches Git state. Everything is as declared in Git.
- **OutOfSync:** Cluster state differs from Git. Need to apply changes.
- **Unknown:** Argo CD can't reach Git or cluster. Can't tell if they match.

**In Part 3:** After you push, Argo CD shows "OutOfSync" briefly, then syncs to "Synced."

### Self-Healing
**Definition:** Automatic correction when cluster state drifts from desired state.
**Example:** Someone manually deletes a pod. Deployment controller automatically creates a new one (to meet replica count).
**In Part 3:** Enabled via `selfHeal: true` in argocd-app.yaml. If you manually edit a pod, Argo CD reverts it.

### Continuous Delivery vs Continuous Deployment
- **CD (Delivery):** Automated testing → verified ready to deploy, but human approves
- **CD (Deployment):** Automatically deployed after tests pass
**In Part 3:** Argo CD does continuous deployment (auto-sync enabled, no human approval).

---

## 13) Key Takeaways (What You Should Remember)

### The Problem Part 3 Solves
**Before GitOps:** You SSH into servers, run `kubectl apply deployment.yaml` manually. If teammates push changes, you might not notice. Chaos.

**With GitOps:** Push to GitHub → Argo CD sees it → cluster updates automatically. Single source of truth. Audit trail every change.

### Why Each Component
- **Docker:** Lightweight VM-like containers
- **K3d:** Fast local Kubernetes (not full production Kubernetes)
- **Argo CD:** Automation engine (watches Git, updates cluster)
- **GitHub:** Source of truth (manifests live here)

### The Flow You Must Understand
1. Edit file locally → `git push`
2. Argo CD polls GitHub
3. Argo CD detects change
4. Argo CD updates cluster **automatically** (no manual kubectl needed)
5. App updated running

### Polling Delay (Why It Doesn't Happen Instantly)
**Default:** Every 3 minutes
**Why:** Tradeoff between responsiveness and resource usage. Polling every second would hammer GitHub API.
**For demos:** Use `kubectl annotate ... refresh=hard` to sync immediately.

### Idempotency (Safe to Repeat)
**Script can run multiple times:** K3d reuses cluster, kubectl apply is idempotent, no conflicts.
**Manifests are idempotent:** Applying same YAML 100 times = applying once.
**This matters:** You don't break things by re-running commands.

### When Things Break
**Golden rule:** Check logs. `kubectl logs` and `kubectl describe` tell you what went wrong.
**Second rule:** Argo CD Application status tells you if Git and cluster match.
**Third rule:** Restart is last resort (should rarely be needed with GitOps).

---

## 14) Further Learning (If You Want to Go Deeper)

### Official Docs
- **Kubernetes:** https://kubernetes.io/docs (dry but authoritative)
- **Argo CD:** https://argo-cd.readthedocs.io (their official docs)
- **K3d:** https://k3d.io (lightweight Kubernetes distro)

### Kubernetes Concepts to Learn
- StatefulSets vs Deployments (when to use each)
- ConfigMaps and Secrets (app configuration)
- PersistentVolumes (data storage)
- Ingress (external routing to services)
- RBAC (who can do what)

### GitOps Concepts to Learn
- Different GitOps tools: Flux, Kapp, Helm (Argo CD alternatives)
- Image scanning and security
- Progressive delivery (canary deployments)
- Multi-cluster GitOps (fleet management)

### Practical Next Steps
1. Change the image to something else (not v1, not v2) and verify auto-sync
2. Add a second container to the deployment and push it
3. Scale replicas from 1 to 3 and watch pods multiply
4. Destroy the cluster and verify you can recreate it with one command
5. Add a second app to `dev` namespace via GitOps

### Key Questions to Ask Yourself
- What happens if you delete a pod manually? Does Argo CD recreate it?
- What happens if you manually scale replicas using `kubectl scale`? Does Argo CD revert it?
- How would you do a blue-green deployment (two parallel versions)?
- How would you set up a second environment (staging cluster) with same app?
- How would you version your deployments?

---

## 15) Quick Reference Commands

```bash
# Cluster Management
k3d cluster list                          # List all locally created clusters
k3d cluster create iot-cluster            # Create a new cluster
k3d cluster delete iot-cluster            # Destroy a cluster
kubectl config current-context            # Which cluster is kubectl using?

# View Status
kubectl get all -n dev                    # Everything in dev namespace
kubectl get pods -n argocd -w             # Watch pods update in real-time
kubectl get applications -n argocd        # All GitOps apps
kubectl describe application playground -n argocd  # Details of one app

# Debugging
kubectl logs -n dev deployment/playground # Pod logs
kubectl exec -n dev deployment/playground -- sh  # Shell into running pod
kubectl explain Deployment               # What fields does Deployment have?

# Argo CD Specific
argocd app list                           # List all apps (CLI)
argocd app sync playground                # Manual sync (CLI)
kubectl annotate application playground -n argocd argocd.argoproj.io/refresh=hard --overwrite

# Port Forwarding
kubectl port-forward svc/playground -n dev 8888:8888 &  # Background
kill %1                                   # Kill background job

# Getting Help
kubectl --help                            # kubectl documentation
kubectl get pods --help                   # Specific command help
kubectl api-resources                     # All Kubernetes resource types
```

---

**Key Takeaway:** Part 3 brings everything together with GitOps automation. You've gone from manually deploying apps (Part 1-2) to having Git as your source of truth, with Argo CD automatically synchronizing your cluster. This is production-grade infrastructure—the same patterns used by companies like GitHub, Google, and Amazon to manage thousands of services.
