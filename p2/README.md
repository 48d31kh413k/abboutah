# Part 2 Documentation: K3s and Three Simple Applications (Ingress Routing)

**TL;DR:** Part 2 demonstrates application deployment and routing in Kubernetes. You'll deploy 3 different web applications to a single K3s cluster and use Ingress to route traffic based on hostname headers. When clients request `app1.com`, they get app1; `app2.com` gets app2 (with 3 replicas for load balancing); everything else defaults to app3.

This document explains:
- **What** Part 2 does and why it matters
- **How** Kubernetes Ingress works
- **Why** we use deployments and replicas
- **How to** deploy, route, and test multi-app infrastructure
- **Key decisions** about networking and scaling

## Table of Contents

1. [What Part 2 is doing (The Big Picture)](#1-what-part-2-is-doing-the-big-picture)
2. [Why each component exists (Architecture Explained)](#2-why-each-component-exists-architecture-explained)
3. [Files and responsibilities (Project Layout)](#3-files-and-responsibilities-project-layout)
4. [Kubernetes manifests deep dive](#4-kubernetes-manifests-deep-dive)
5. [How Ingress routing works (Traffic Flow)](#5-how-ingress-routing-works-traffic-flow)
6. [How to run everything (Step-by-Step)](#6-how-to-run-everything-step-by-step)
7. [Verifying the setup (Testing and Validation)](#7-verifying-the-setup-testing-and-validation)
8. [Common issues and fixes (Troubleshooting)](#8-common-issues-and-fixes-troubleshooting)
9. [Architecture Overview (Multi-App Topology)](#9-architecture-overview-multi-app-topology)
10. [Key Concepts (Understanding Deployments & Ingress)](#10-key-concepts-understanding-deployments--ingress)
11. [Quick Reference Commands](#11-quick-reference-commands)
12. [Summary for Your Evaluators](#12-summary-for-your-evaluators)

---

## 1) What Part 2 is doing (The Big Picture)

**The Problem:** You have Kubernetes running (from Part 1), but how do you actually run multiple applications and route traffic to them?

**The Solution:** Deploy 3 applications as Kubernetes Deployments, expose them via Services, and use Ingress to route traffic based on the hostname in the HTTP request.

**Part 2 Flow:**
```
User accesses 192.168.56.110 with Host: app1.com 
→ Ingress receives request 
→ Routes to "app1" service 
→ Service load-balances to app1 pod(s)
→ App1 container returns response
```

**What you'll learn:**
- How to package applications as Kubernetes Deployments
- What Services do (expose running pods internally and externally)
- How Ingress controllers route traffic based on HTTP headers
- How replication improves availability (app2 has 3 copies)
- How Kubernetes self-healing works (if a pod crashes, it restarts)

---

## 2) Why each component exists (Architecture Explained)

### Kubernetes Namespace
**What it is:** A virtual cluster within the physical cluster. Isolates resources.
**Why it's here:** Keeps your apps organized. You could put all 3 apps in the default namespace, but best practice is to group them.
**For you:** All your apps will run in the same namespace (or separate ones if you prefer).

### Deployment (app1, app2, app3)
**What it is:** A Kubernetes object that describes how many containers you want running, what image to use, environment variables, ports, etc.
**Why it's here:** Instead of running 1 container and hoping it doesn't crash, a Deployment ensures that if a container dies, Kubernetes automatically restarts it.
**Key benefit:**
  ```yaml
  spec:
    replicas: 3  # Always keep 3 copies running
  ```
If one fails, Kubernetes automatically starts a new one to maintain 3.

### Pod
**What it is:** A wrapper around 1+ containers. Smallest deployable unit in Kubernetes.
**Why it's here:** Pods are the actual running instances. A Deployment creates them automatically.
**For you:** You don't manually manage pods—the Deployment does.

### Service
**What it is:** A stable IP/DNS name that points to one or more pods.
**Why it's here:** Pods come and go (die, restart, get recreated). Services abstract away this churn and provide a stable endpoint.
**Example:**
```
Pod #1 (10.42.0.5)    \
Pod #2 (10.42.0.6)  ---> Service (app1-service:8080) ---> External traffic
Pod #3 (10.42.0.7)    /
```
Clients don't need to know which pod to hit. They hit the Service, which load-balances to any healthy pod.

### Ingress
**What it is:** A Kubernetes object that routes external HTTP/HTTPS requests into your cluster based on hostname, path, TLS, etc.
**Why it's here:** Services give you internal networking. Ingress brings external traffic in. The Ingress controller (built into K3s) reads Ingress rules and configures the reverse proxy.
**Example rule:**
```yaml
- host: app1.com
  http:
    paths:
    - path: /
      backend:
        serviceName: app1
        servicePort: 8080
```
Means: if the `Host` header is `app1.com`, forward to the `app1` service on port 8080.

### Container Image
**What it is:** A packaged application (your code, libraries, runtime) ready to execute.
**Why it's here:** Kubernetes doesn't run source code directly. It runs containers.
**For you:** You'll use existing images (nginx, httpbin, your own apps) or build your own.

---

## 3) Files and responsibilities (Project Layout)

```
p2/
├── Vagrantfile         # Single VM with K3s in server mode
├── scripts/
│   ├── install.sh      # Installs K3s and (optionally) kubectl on host
│   └── [other helpers] # Any deployment automation scripts
└── confs/
    ├── namespace.yaml  # Creates a namespace for your apps
    ├── app1.yaml       # Deployment + Service for app1
    ├── app2.yaml       # Deployment (3 replicas) + Service for app2
    ├── app3.yaml       # Deployment + Service for app3
    └── ingress.yaml    # Ingress rule for routing
```

### Vagrantfile
- Creates 1 VM (not 2 like Part 1)
- Hostname: `{login}S` (e.g., `bmS`)
- IP: 192.168.56.110
- Installs K3s in **server mode** (not controller/agent, just server)
- K3s server runs everything on the same machine

### scripts/install.sh
- Installs K3s in server mode
- May configure kubectl on the host machine (optional but helpful)
- May apply the initial namespace and configurations

### confs/namespace.yaml
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-apps  # Or whatever you name it
```
Creates a namespace to isolate your applications.

### confs/app1.yaml, app2.yaml, app3.yaml
Each contains a Deployment and Service. Example structure:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1
  namespace: my-apps
spec:
  replicas: 1  # 1 for app1 and app3
  selector:
    matchLabels:
      app: app1
  template:
    metadata:
      labels:
        app: app1
    spec:
      containers:
      - name: app1
        image: some-image:latest
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: app1-service
  namespace: my-apps
spec:
  selector:
    app: app1
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 8080
  type: ClusterIP
```

For app2, set `replicas: 3`.

### confs/ingress.yaml
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
  namespace: my-apps
spec:
  rules:
  - host: app1.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app1-service
            port:
              number: 8080
  - host: app2.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2-service
            port:
              number: 8080
  - host: app3.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app3-service
            port:
              number: 8080
```

Rules for all three apps. The one without a hostname (if you have one) becomes the default backend.

---

## 4) Kubernetes manifests deep dive

### Deployment: Why replicas matter
```yaml
spec:
  replicas: 3
```
This tells Kubernetes: "Keep 3 copies of this pod running all the time."

**What happens when you deploy:**
- Kubernetes starts 3 pod instances
- Each pod runs your container
- If one pod crashes, Kubernetes immediately starts a replacement
- If you scale to 5 replicas, Kubernetes gradually starts 2 more
- This is **self-healing** and **scalability** built-in

### Service: Stable networking
```yaml
spec:
  selector:
    app: app1
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
```

**What it does:**
- Finds all pods with `app: app1` label
- Exposes them on port 8080
- Provides a stable DNS name: `app1-service.my-apps.svc.cluster.local` (or just `app1-service` within the namespace)
- Load-balances requests round-robin style to any healthy pod

**Service Types:**
- `ClusterIP`: Internal-only (pods talk to each other)
- `NodePort`: Opens a port on all nodes (advanced, rarely used in Part 2)
- `LoadBalancer`: For cloud providers (not applicable locally)

### Ingress: External routing
```yaml
- host: app1.com
  http:
    paths:
    - path: /
```

**What it does:**
- Listens on port 80 (HTTP)
- When a request comes with `Host: app1.com`, forwards to the `app1-service`
- K3s comes with Traefik Ingress controller built-in, so this "just works"

**To test locally:**
You need to add entries to your `/etc/hosts` file:
```
192.168.56.110  app1.com
192.168.56.110  app2.com
192.168.56.110  app3.com
```

Then `curl http://app1.com` will resolve to Ingress and get routed to app1.

---

## 5) How Ingress routing works (Traffic Flow)

### Request journey (from browser to app)

```
┌─────────────────────────────────────┐
│ Browser/Client                       │
│ curl http://app1.com                │
└──────────────┬──────────────────────┘
               │
               ▼
        ┌──────────────────┐
        │ Host resolution  │
        │ app1.com → 192.168.56.110 │
        │ (via /etc/hosts) │
        └──────────┬───────┘
                   │
                   ▼
        ┌──────────────────────────┐
        │ HTTP Request sent to    │
        │ Traefik Ingress          │
        │ (port 80)                │
        │ Host: app1.com           │
        └──────────┬───────────────┘
                   │
                   ▼
        ┌──────────────────────────┐
        │ Traefik Ingress Controller│
        │ Reads Ingress rules      │
        │ Matches: app1.com → app1-service │
        └──────────┬───────────────┘
                   │
                   ▼
        ┌──────────────────────────┐
        │ Service (app1-service)    │
        │ Picks healthy pod        │
        │ pod-app1-12345           │
        └──────────┬───────────────┘
                   │
                   ▼
        ┌──────────────────────────┐
        │ Pod (running app1)        │
        │ Container returns HTML   │
        │ or JSON response         │
        └──────────┬───────────────┘
                   │
                   ▼
        ┌──────────────────────────┐
        │ Response back through    │
        │ Service → Ingress → Browser│
        └──────────────────────────┘
```

### Load-balancing (app2 with 3 replicas)
```
Request 1 → Service → picks app2-pod-1
Request 2 → Service → picks app2-pod-2  (round-robin)
Request 3 → Service → picks app2-pod-3
Request 4 → Service → picks app2-pod-1 (round-robin again)
```

If app2-pod-2 crashes:
```
Request → Service → skips pod-2, hits pod-1 or pod-3
Kubernetes → detects pod-2 is dead → starts a new pod-2
```

---

## 6) How to run everything (Step-by-Step)

### Prerequisites (same as Part 1)
- Vagrant installed
- VirtualBox/VMware/Parallels
- 2+ GB free RAM
- 20+ GB free disk space

### Launch the VM
```bash
cd p2
vagrant up
# Creates 1 VM and installs K3s in server mode
# Total time: 5-10 minutes
```

### Verify K3s is running
```bash
vagrant ssh YOUR_LOGINS
kubectl get nodes
# Should show: 1 Ready node

kubectl get pods --all-namespaces
# Should see system pods
```

### Create your applications
Deploy from inside the VM (or from host if kubeconfig is copied):
```bash
vagrant ssh YOUR_LOGINS

# Option 1: Apply all configs from confs/
kubectl apply -f /path/to/confs/namespace.yaml
kubectl apply -f /path/to/confs/app1.yaml
kubectl apply -f /path/to/confs/app2.yaml
kubectl apply -f /path/to/confs/app3.yaml
kubectl apply -f /path/to/confs/ingress.yaml

# Or apply all at once:
kubectl apply -f /path/to/confs/

# Verify deployments are running
kubectl get deployments -n my-apps
kubectl get pods -n my-apps
kubectl get services -n my-apps
kubectl get ingress -n my-apps
```

### Verify Ingress is working
```bash
# Inside the VM or host (if kubectl accessible)
kubectl get ingress -n my-apps

##### SCREENSHOT NEEDED HERE ###
# Capture: `kubectl get ingress` output

# Test routing from inside the VM
vagrant ssh YOUR_LOGINS
curl http://192.168.56.110/
# Should hit the default backend (usually app3)

curl -H "Host: app1.com" http://192.168.56.110/
# Should hit app1

curl -H "Host: app2.com" http://192.168.56.110/
# Should hit app2 (and hit different replicas on each request)

##### SCREENSHOT NEEDED HERE ###
# Capture: curl requests showing different app responses
```

### Test from your host (optional)
Add entries to `/etc/hosts`:
```bash
# macOS / Linux
sudo nano /etc/hosts
# Add:
192.168.56.110  app1.com
192.168.56.110  app2.com
192.168.56.110  app3.com
# Save (Ctrl+O, Enter, Ctrl+X)

# Windows (Notepad as admin)
C:\Windows\System32\drivers\etc\hosts
# Add the same lines

# Now test from your browser:
# Open browser → navigate to http://app1.com
# You should see app1
```

---

## 7) Verifying the setup (Testing and Validation)

### Checklist for Part 2 requirements

- [ ] Single VM created with correct hostname and IP (192.168.56.110)
- [ ] K3s server running in server mode
- [ ] 3 web applications deployed
- [ ] Each app is accessible via its Host header (app1.com, app2.com, app3.com)
- [ ] Default route (no Host header or unknown Host) returns app3
- [ ] app2 has 3 replicas visible in `kubectl get pods`
- [ ] Ingress rules are configured and active
- [ ] Services are load-balancing correctly

### Commands to verify each requirement

```bash
# 1. Check Vagrant status
vagrant status

##### SCREENSHOT NEEDED HERE ###
# Capture: `vagrant status` showing 1 running VM

# 2. Verify VM details
vagrant ssh YOUR_LOGINS
hostname
ip a show enp0s8
# Should show: hostname = YOUR_LOGINS, IP = 192.168.56.110

# 3. Check K3s server is running
systemctl status k3s
# Should show: active (running)
# Look for: "server" in the status output

##### SCREENSHOT NEEDED HERE ###
# Capture: systemctl status k3s output

# 4. Check nodes
kubectl get nodes
# Should show: 1 node, Status = Ready

# 5. Check deployments
kubectl get deployments -n my-apps
# Should show: app1, app2, app3
# Expected output:
# NAME             READY   UP-TO-DATE   AVAILABLE   AGE
# app1             1/1     1            1           Xm
# app2             3/3     3            3           Xm
# app3             1/1     1            1           Xm

##### SCREENSHOT NEEDED HERE ###
# Capture: `kubectl get deployments` showing all 3 apps deployed

# 6. Check pods
kubectl get pods -n my-apps
# Should show: 1 pod for app1, 3 pods for app2, 1 pod for app3

##### SCREENSHOT NEEDED HERE ###
# Capture: `kubectl get pods` showing app2 with 3 replicas

# 7. Check services
kubectl get services -n my-apps
# Should show: app1-service, app2-service, app3-service
# All should have internal IPs

# 8. Check Ingress
kubectl get ingress -n my-apps
kubectl describe ingress my-ingress -n my-apps  # More detail

##### SCREENSHOT NEEDED HERE ###
# Capture: `kubectl get ingress` and describe output

# 9. Test routing (from VM or host)
curl -H "Host: app1.com" http://192.168.56.110/
# Should return app1's response

curl -H "Host: app2.com" http://192.168.56.110/
# Should return app2's response

curl -H "Host: app3.com" http://192.168.56.110/
# Should return app3's response

curl http://192.168.56.110/
# Should return app3's response (default)

##### SCREENSHOT NEEDED HERE ###
# Capture: curl requests showing different responses for each Host header
```

---

## 8) Common issues and fixes (Troubleshooting)

### Issue: Ingress created but requests get "404" or "Connection refused"
**Cause:** Pods not running, services not created, or Traefik not recognized the Ingress rules yet.
**Fix:**
```bash
# Check if pods are actually running
kubectl get pods -n my-apps
# If any are NotReady, check logs:
kubectl logs pod-name -n my-apps

# Check if services exist
kubectl get services -n my-apps

# Check Ingress status
kubectl get ingress -n my-apps
# Look at ADDRESS column—should have an IP assigned

# Restart Traefik (sometimes needed after Ingress creation)
kubectl rollout restart -n kube-system deployment/traefik
sleep 10
kubectl get ingress -n my-apps  # Check again
```

### Issue: app2 shows "2/3" or "0/3" instead of "3/3" replicas
**Cause:** Pods not finding resources, or image pull failing.
**Fix:**
```bash
kubectl get pods -n my-apps
# Look for pods with "Pending", "ImagePullBackOff", or "CrashLoopBackOff"

# Get detailed error
kubectl describe pod app2-deployment-xxxxx -n my-apps
# Look at Events section for reasons

# Check logs
kubectl logs app2-deployment-xxxxx -n my-apps

# If image pull fails, verify image name:
kubectl get deployment app2 -n my-apps -o yaml | grep image
```

### Issue: Can access from host but not from VM (or vice versa)
**Cause:** Network connectivity or `/etc/hosts` not set correctly.
**Fix:**
```bash
# From VM:
ping 192.168.56.1  # Host IP
# If no response, check Vagrant networking

# From host:
ping 192.168.56.110  # VM IP
# If no response, check VirtualBox network settings

# Also verify /etc/hosts (host machine)
cat /etc/hosts | grep app
# Should show:
# 192.168.56.110  app1.com
# 192.168.56.110  app2.com
# 192.168.56.110  app3.com
```

### Issue: curl succeeds inside VM but browser shows error from host
**Cause:** `/etc/hosts` entries not reloaded, DNS cache, or CORS issues.
**Fix:**
```bash
# macOS: flush DNS cache
sudo dscacheutil -flushcache

# Linux: depends on DNS daemon, but try
sudo systemctl restart systemd-resolved

# Windows: Open Command Prompt as Admin and run:
ipconfig /flushdns

# Verify entries are correct:
ping app1.com
# Should resolve to 192.168.56.110
```

### Issue: Pods keep restarting (CrashLoopBackOff)
**Cause:** Application crashing, missing dependencies, or bad environment.
**Fix:**
```bash
# Check pod logs
kubectl logs app1-deployment-xxxxx -n my-apps --tail=50

# If using a simple test image, ensure port is correct:
kubectl get deployment app1 -n my-apps -o yaml | grep containerPort

# If custom app, ensure Dockerfile/entrypoint is correct
```

---

## 9) Architecture Overview (Multi-App Topology)

```
┌──────────────────────────────────────────────────────────────┐
│ Kubernetes Cluster (K3s Server Mode)                         │
│ Running inside: YOUR_LOGINS VM (192.168.56.110)             │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Traefik Ingress Controller                             │ │
│  │ Listens on port 80 (HTTP)                              │ │
│  │ Routes based on Host header                            │ │
│  └──────────────┬────────────────────────────────────────┘ │
│                 │                                            │
│    ┌────────────┼────────────┬─────────────────┐           │
│    │            │            │                  │           │
│  Host: app1.com│   Host: app2.com   │  Host: app3.com      │
│    │            │            │                  │           │
│    ▼            ▼            ▼                  ▼           │
│ ┌─────┐  ┌──────▼──────┐  ┌─────┐           ┌──────┐      │
│ │app1 │  │ app2-service │  │app3 │           │Default│     │
│ │servi│  │ [Load Balanc]│  │servi│           │Backend│     │
│ │ce   │  └──────┬───────┘  │ce   │           │(app3) │     │
│ └──┬──┘         │          └──┬──┘           └──────┘      │
│    │            │             │                            │
│    ▼            ▼             ▼                            │
│  ┌───┐      ┌───┬───┬───┐    ┌───┐                        │
│  │Pod│      │Pod│Pod│Pod│    │Pod│                        │
│  │ 1 │      │ 1 │ 2 │ 3 │    │ 1 │                        │
│  │   │      │   │   │   │    │   │                        │
│  │APP1      │      APP2      │    │APP3                   │
│  └───┴──────┴───┴───┴───┴────┴───┘                        │
│                                                              │
│  my-apps namespace                                          │
└──────────────────────────────────────────────────────────────┘
       │                                                
       │ port 80
       └─────────────────────────────────────────►  Your Host Machine
       (HTTP requests from browser/curl)
```

---

## 10) Key Concepts (Understanding Deployments & Ingress)

### Desired State vs Actual State
Kubernetes is always trying to match "actual state" to "desired state."

**Desired state** = what you wrote in YAML (3 replicas of app2)
**Actual state** = what's currently running

If they don't match, Kubernetes takes action to fix it.

### Labels and Selectors
```yaml
metadata:
  labels:
    app: app1
---
selector:
  matchLabels:
    app: app1
```
Labels are how Kubernetes groups resources. A Service finds pods by label selector.

### Replica Sets
When you create a Deployment, Kubernetes automatically creates a ReplicaSet underneath. The ReplicaSet ensures N pods are always running.

### Self-healing
- Pod crashes → Kubernetes restarts it
- Node goes down → Kubernetes moves pods to another node
- You delete a pod → The ReplicaSet creates a new one

### Rolling Updates
When you change the image in a Deployment, Kubernetes does a rolling update:
- Starts new pods with new image
- Terminates old pods gradually
- Ensures service availability throughout

### Port vs targetPort
```yaml
ports:
- port: 8080        # Port the Service listens on
  targetPort: 8080  # Port the container is actually running on
```
If your container runs on port 9000, set `port: 8080, targetPort: 9000`.

---

## 11) Quick Reference Commands

```bash
# Vagrant commands
vagrant up                           # Start the VM
vagrant ssh YOUR_LOGINS              # SSH into the VM
vagrant destroy                      # Tear down

# kubectl: Deployments
kubectl get deployments -n my-apps                    # List
kubectl describe deployment app2 -n my-apps           # Details
kubectl scale deployment app2 --replicas=5 -n my-apps  # Scale to 5
kubectl logs deployment/app1 -n my-apps --tail=50     # Last 50 lines of logs

# kubectl: Pods
kubectl get pods -n my-apps           # List all pods
kubectl get pods -n my-apps -o wide   # More detail
kubectl describe pod pod-name -n my-apps  # Detailed info
kubectl logs pod-name -n my-apps      # Application logs
kubectl exec -it pod-name -n my-apps -- /bin/sh  # Shell into pod

# kubectl: Services
kubectl get svc -n my-apps            # List services
kubectl describe svc app1-service -n my-apps  # Details

# kubectl: Ingress
kubectl get ingress -n my-apps        # List Ingress rules
kubectl describe ingress my-ingress -n my-apps  # Details
kubectl edit ingress my-ingress -n my-apps  # Edit rules

# kubectl: Apply and Delete
kubectl apply -f /path/to/manifest.yaml   # Create/update resource
kubectl delete -f /path/to/manifest.yaml  # Delete resource
kubectl apply -f /path/to/confs/          # Apply all files in folder

# kubectl: Debugging
kubectl get events -n my-apps                   # Recent cluster events
kubectl get all -n my-apps                      # All resources in namespace
```

---

## 12) Summary for Your Evaluators

**What to show during evaluation:**

1. **VM running with correct specs**
   ```bash
   vagrant status
   # Show: YOUR_LOGINS running
   vagrant ssh YOUR_LOGINS
   hostname && ip a show enp0s8
   # Show: Correct hostname and 192.168.56.110 IP
   ```
   ##### SCREENSHOT NEEDED HERE ###
   # Capture: `vagrant status` and VM details showing correct hostname and IP

2. **All 3 apps deployed**
   ```bash
   kubectl get deployments -n my-apps
   # Show: 3 deployments (app1, app2, app3)
   ```
   ##### SCREENSHOT NEEDED HERE ###
   # Capture: `kubectl get deployments` showing all 3 apps with READY status

3. **app2 has 3 replicas**
   ```bash
   kubectl get pods -n my-apps
   # Show: 3 pods for app2, 1 each for app1 and app3
   ```
   ##### SCREENSHOT NEEDED HERE ###
   # Capture: `kubectl get pods` showing app2 with 3 pod instances running

4. **Ingress rules working**
   ```bash
   kubectl get ingress -n my-apps
   # Show: Ingress with rules for app1.com, app2.com, app3.com
   ```
   ##### SCREENSHOT NEEDED HERE ###
   # Capture: `kubectl get ingress` showing configured rules and assigned IP

5. **Load-balancing each host correctly**
   ```bash
   # Inside VM or from host (if /etc/hosts set):
   curl -H "Host: app1.com" http://192.168.56.110/
   # Show: app1 response
   
   curl -H "Host: app2.com" http://192.168.56.110/
   # Show: app2 response (run multiple times to show load-balancing)
   
   curl http://192.168.56.110/
   # Show: app3 response (default backend)
   ```
   ##### SCREENSHOT NEEDED HERE ###
   # Capture: curl requests showing different apps responding to different hosts

6. **Browser access (optional, if `/etc/hosts` set up)**
   ```bash
   # Open browser
   # Navigate to http://app1.com
   # Show: app1 page displayed
   # Navigate to http://app2.com
   # Show: app2 page
   # Navigate to http://app3.com or any other host
   # Show: app3 page
   ```
   ##### SCREENSHOT NEEDED HERE ###
   # Capture: Browser screenshots of app1.com, app2.com, and app3.com pages

7. **Self-healing demo (bonus)**
   ```bash
   # Delete a pod
   kubectl delete pod app2-deployment-xxxxx -n my-apps
   # Immediately list pods
   kubectl get pods -n my-apps
   # Show: New pod being created to replace deleted one
   ```
   ##### SCREENSHOT NEEDED HERE ###
   # Capture: Pod deletion and automatic recreation by Kubernetes

---

**Key Takeaway:** Part 2 teaches you how Kubernetes applications communicate and scale. You've gone from a bare cluster (Part 1) to a running, load-balanced, multi-app production-like setup. Ingress is the key—without it, you'd have no way to route external traffic. In Part 3, you'll add GitOps automation on top of this.
