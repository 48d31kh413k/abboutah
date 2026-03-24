# Bonus Quickstart (Simple)

## 1) Prerequisite

Part 3 must already be running (`argocd` + `dev` namespaces alive).

## 2) Install GitLab in `gitlab` namespace

```bash
cd ~/Desktop/Inception-of-things/bonus/scripts
chmod +x install.sh
./install.sh
```

## 3) Open GitLab

```bash
kubectl port-forward svc/gitlab-webservice-default -n gitlab 8081:8181
```

Browse to `http://localhost:8081`.

- Username: `root`
- Password: `InsecurePassword1!`

Or print password:

```bash
./gitlab-helper.sh show-password
```

## 4) Mirror your repository

```bash
./gitlab-helper.sh mirror-repo https://github.com/<you>/<repo>.git root <password>
```

## 5) Point Argo CD to GitLab

```bash
./gitlab-helper.sh configure-argocd http://localhost:8081/root/<repo>.git
```

This app syncs from `p3/confs/app` (same as mandatory part).

## 6) Validate

```bash
./gitlab-helper.sh show-status
kubectl get app -n argocd
kubectl get pods -n gitlab
kubectl get pods -n dev
```

## 7) Defense demo

1. Change image tag in `p3/confs/app/deployment.yaml` in the GitLab repo (`v1` to `v2`).
2. Commit and push.
3. Show Argo CD sync.
4. Verify with `curl http://localhost:8888` after port-forwarding `svc/playground`.
