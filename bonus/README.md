# Bonus Part: K3d + GitLab + Argo CD

## Overview

This bonus **extends Part 3** by adding **GitLab** as a local, self-hosted Git repository. Instead of using GitHub, your Argo CD instance will sync from a GitLab repository running locally in your Kubernetes cluster.

**Important:** This bonus assumes you have already completed **Part 3** and have a working K3d cluster with Argo CD running on your VM.

## Architecture

```
┌──────────────────────────────────────────────┐
│         K3d Cluster (Local)                  │
│ ┌────────────┐  ┌────────────┐  ┌─────────┐ │
│ │  GitLab    │  │  Argo CD   │  │  App    │ │
│ │ (gitlab)   │→ │  (argocd)  │→ │  (dev)  │ │
│ │ namespace  │  │ namespace  │  │namespace│ │
│ └────────────┘  └────────────┘  └─────────┘ │
└──────────────────────────────────────────────┘
         ↑
   Push configs & app
   (git push to local GitLab)
```

## Prerequisites

- **Part 3 setup already running** (K3d cluster from Part 3)
- K3d, Docker, kubectl, and Helm already installed
- VM with SSH access configured
- Administrative access to the cluster

## Installation

**Prerequisites:** You must have Part 3 already running with a K3d cluster.

1. **SSH into your VM (where Part 3 is running):**
   ```bash
   ssh root@127.0.0.1 -p 2222
   ```

2. **Run the installation script:**
   ```bash
   cd ~/Desktop/Inception-of-things/bonus/scripts
   chmod +x install.sh
   ./install.sh
   ```

The script will add to your existing K3d cluster:
- Create `gitlab` namespace with GitLab deployment
- Create additional port mappings for GitLab
- Deploy GitLab using Helm
- Reconfigure Argo CD to sync from GitLab instead of GitHub
- Output new access credentials and commands

## Accessing Services

### From the VM:

**GitLab:**
```bash
kubectl port-forward svc/gitlab-webservice -n gitlab 443:8181 &
curl https://localhost  # Or use a browser
# Username: root
# Password: Check output of install.sh
```

**Argo CD:**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
# Browse to https://localhost:8080
# Username: admin
# Password: Check output of install.sh
```

**Playground App:**
```bash
kubectl port-forward svc/playground -n dev 8888:8888 &
curl http://localhost:8888
```

### From your macOS:

In separate terminals, create SSH tunnels:

```bash
# Terminal 1: GitLab
ssh -L 443:localhost:443 root@127.0.0.1 -p 2222 -N

# Terminal 2: Argo CD
ssh -L 8080:localhost:8080 root@127.0.0.1 -p 2222 -N

# Terminal 3: Playground
ssh -L 8888:localhost:8888 root@127.0.0.1 -p 2222 -N
```

Then from your Mac browser:
- GitLab: `https://localhost`
- Argo CD: `http://localhost:8080`
- Playground: `http://localhost:8888`

## Setting Up GitLab Repository

1. **Log in to GitLab** (`https://localhost`)
   - Username: `root`
   - Password: From install.sh output

2. **Create a new project:**
   - Click "New project"
   - Name: `inception-of-things` (or your preferred name)
   - Visibility: Public (required for Argo CD to access)
   - Initialize with README

3. **Mirror your project:**
   ```bash
   # In your local macOS terminal
   git clone https://github.com/YOUR_GITHUB/inception-of-things.git temp
   cd temp
   git push --mirror https://gitlab.local/root/inception-of-things.git
   cd ..
   rm -rf temp
   ```

4. **Configure Argo CD:**
   - Edit `confs/argocd-app.yaml` and update the `repoURL` to match your GitLab project
   - Apply the updated configuration:
     ```bash
     kubectl delete app playground-gitlab -n argocd 2>/dev/null || true
     kubectl apply -f confs/argocd-app.yaml
     ```

## GitOps Workflow with GitLab

This setup follows the same GitOps principles as Part 3, but with GitLab as the source of truth:

1. **Update deployment version locally:**
   ```bash
   git clone https://gitlab.local/root/inception-of-things.git
   cd inception-of-things/bonus/confs/app
   # Edit deployment.yaml, change image tag from v1 to v2
   git add deployment.yaml
   git commit -m "Bump playground to v2"
   git push
   ```

2. **Argo CD auto-syncs within 3 minutes**

3. **Verify the update:**
   ```bash
   curl http://localhost:8888/
   # Should return: {"status":"ok", "message": "v2"}
   ```

## Managing Self-Signed Certificates

GitLab with HTTPS may use self-signed certificates. If Argo CD has issues accessing GitLab:

1. **Get GitLab's certificate:**
   ```bash
   kubectl get secret -n gitlab gitlab-self-signed-cert -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/gitlab-cert.pem
   ```

2. **Configure Argo CD to trust it:**
   ```bash
   kubectl create secret generic argocd-repo-server-tls \
     --from-file=cert=/tmp/gitlab-cert.pem \
     -n argocd
   ```

## Troubleshooting

**GitLab not starting:**
- Wait 2-3 minutes for GitLab to fully initialize
- Check pod status: `kubectl get pods -n gitlab`
- View logs: `kubectl logs -n gitlab -l app=gitlab-webservice`

**Argo CD can't access GitLab:**
- Verify GitLab is running: `kubectl get pods -n gitlab`
- Check repository URL in `argocd-app.yaml`
- Ensure the repository is public or add credentials to Argo CD

**Port conflicts:**
- If ports 443, 8080, or 8888 are already in use, modify port mappings in `install.sh`

## Cleanup

To remove the entire K3d cluster:
```bash
k3d cluster delete iot-cluster
```

## Key Differences from Part 3

| Feature | Part 3 (GitHub) | Bonus (GitLab) |
|---------|---|---|
| Repository Host | GitHub.com | Local GitLab in K8s |
| Access | Public GitHub | Local only |
| Setup Complexity | Simple | Medium (Helm required) |
| Performance | Network-dependent | Local (faster) |
| Scalability | GitHub-hosted | Limited to K3d resources |

## Learning Outcomes

By completing this bonus:
- ✅ Understand how to deploy complex applications with Helm
- ✅ Set up a self-hosted Git service in Kubernetes
- ✅ Integrate local Git repositories with Argo CD
- ✅ Manage certificate trust between services
- ✅ Master GitOps with a production-like setup

## References

- [GitLab Helm Chart](https://docs.gitlab.com/ee/install/kubernetes/)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [K3d Documentation](https://k3d.io/)
