# Bonus: GitLab Installation Guide

## ✅ Prerequisites

**Part 3 must be completed and running:**
- K3d cluster with Argo CD running
- Playground app deployed and accessible
- kubectl and Helm installed on VM
- At least 5GB free disk space

## Installation (5 minutes)

### Step 1: SSH into VM
```bash
ssh root@127.0.0.1 -p 2222
```

### Step 2: Run Installation Script
```bash
cd ~/Desktop/Inception-of-things/bonus/scripts
chmod +x install.sh
./install.sh
```

⏳ **Wait 15-20 minutes** for GitLab to initialize in background

### Step 3: Verify Installation
```bash
# Check GitLab pods
kubectl get pods -n gitlab

# Get GitLab pods status
kubectl describe pod -n gitlab -l app=gitlab-webservice-default
```

### Step 4: Access Services from Mac

**Terminal 1 - Argo CD** (Part 3)
```bash
ssh -L 8080:localhost:8080 root@127.0.0.1 -p 2222 -N
```
→ Open http://localhost:8080

**Terminal 2 - Playground App** (Part 3)
```bash
ssh -L 8888:localhost:8888 root@127.0.0.1 -p 2222 -N
```
→ Open http://localhost:8888

**Terminal 3 - GitLab** (Bonus - once ready)
```bash
ssh -L 8443:localhost:443 root@127.0.0.1 -p 2222 -N
```
→ Open http://localhost (when GitLab is ready)

### Step 5: Get GitLab Credentials

Once GitLab pods are `Running`:
```bash
# Get initial root password
kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath="{.data.password}" | base64 -d

# Access URL
http://localhost (or http://gitlab.k3d.gitlab.com)
Username: root
```

## What's Deployed

| Component | Status | Location |
|-----------|--------|----------|
| Argo CD (Part 3) | ✓ Already running | argocd namespace |
| Playground App (Part 3) | ✓ Already running | dev namespace |
| GitLab (Bonus) | Installing... | gitlab namespace |

## Troubleshooting

**GitLab taking too long?**
```bash
# Check GitLab logs
kubectl logs -n gitlab -f deployment/gitlab-webservice-default

# Check if any pods are stuck
kubectl describe pod -n gitlab
```

**Port conflicts?**
```bash
# Check what's using port 443
lsof -i :443

# Free up space if needed
docker system prune -a -f
```
- GitLab: `https://localhost:8443`
- Argo CD: `http://localhost:8080`
- Playground: `http://localhost:8888`

## Testing GitOps Sync

### Option A: Using provided script
```bash
cd ~/Desktop/Inception-of-things/bonus/scripts
./gitlab-helper.sh mirror-repo https://github.com/YOUR/inception-of-things root PASSWORD
./gitlab-helper.sh configure-argocd https://gitlab.local/root/inception-of-things.git
```

### Option B: Manual steps
1. Log in to GitLab (`https://localhost`)
2. Create project: `inception-of-things`
3. Clone locally: `git clone https://gitlab.local/root/inception-of-things.git`
4. Copy files from bonus folder into it
5. Push to GitLab
6. Apply Argo CD app:
   ```bash
   kubectl apply -f confs/argocd-app.yaml
   ```

## That's it!

Your GitLab instance will now:
- ✅ Host your project
- ✅ Be monitored by Argo CD
- ✅ Auto-deploy on commits
- ✅ Manage your Kubernetes cluster as code

## Useful Commands

**Check GitLab status:**
```bash
kubectl get pods -n gitlab
```

**Check Argo CD status:**
```bash
kubectl get app -n argocd
kubectl describe app playground-gitlab -n argocd
```

**View logs:**
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
kubectl logs -n gitlab -l app=gitlab-webservice
```

**Manual sync:**
```bash
kubectl patch app playground-gitlab -n argocd -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' --type merge
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Disk space full (pods won't start) | On VM run: `k3d cluster delete iot-cluster` then `docker system prune -a -f --volumes && docker volume rm $(docker volume ls -q) 2>/dev/null \|\| true` then `df -h` to verify. Need at least 5GB free. Then reinstall. |
| Port already in use | Edit `install.sh` to use different ports |
| GitLab won't start | Wait 3-5 minutes, check `kubectl logs -n gitlab` |
| Argo CD can't access GitLab | Ensure repository URL is correct and public |
| SSL certificate errors | See certificate section in main README |

## Next Steps

1. Push your inception-of-things project to GitLab
2. Update deployment.yaml to change image from v1 to v2
3. Commit and push
4. Watch Argo CD auto-sync in real-time
5. Verify with `curl http://localhost:8888`

Enjoy true GitOps with local GitLab! 🚀
