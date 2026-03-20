# Bonus: Quick Start Guide

## Prerequisites

✅ **Part 3 must be completed and running**
- K3d cluster with Argo CD already set up
- kubectl, k3d, and Helm already installed
- VM is running and accessible

## 5-Minute Setup

### Steps

**1. SSH into VM:**
```bash
ssh root@127.0.0.1 -p 2222
```

**2. Run install script:**
```bash
cd ~/Desktop/Inception-of-things/bonus/scripts
chmod +x install.sh
./install.sh
```
⏳ Installation takes ~10-15 minutes (mainly GitLab initialization)

**3. Once complete, you'll see:**
- GitLab credentials
- Argo CD credentials
- Port-forward commands

**4. From your Mac, open three terminals:**

Terminal 1 (GitLab):
```bash
ssh -L 8443:localhost:443 root@127.0.0.1 -p 2222 -N
```

Terminal 2 (Argo CD):
```bash
ssh -L 8080:localhost:8080 root@127.0.0.1 -p 2222 -N
```

Terminal 3 (Playground):
```bash
ssh -L 8888:localhost:8888 root@127.0.0.1 -p 2222 -N
```

**5. In your browser:**
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
