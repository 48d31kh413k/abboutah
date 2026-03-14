# Part 3 Documentation: K3d + Argo CD (How and Why)

This document explains:
- how the Part 3 setup is structured,
- why each component is used,
- and how to run and verify everything end-to-end.

## 1) What Part 3 is doing

Part 3 implements a local GitOps workflow:
- K3d creates a lightweight Kubernetes cluster using Docker.
- Argo CD runs inside that cluster.
- Argo CD watches your GitHub repository.
- The app in namespace `dev` is deployed automatically from Git.
- Changing image tag in Git (for example `v1` to `v2`) triggers automatic rollout.

## 2) Why each component exists

- Docker:
  K3d runs Kubernetes nodes as Docker containers.

- K3d:
  Fast local Kubernetes setup, easier than managing full VMs for this part.

- kubectl:
  Used to inspect and manage cluster resources.

- Argo CD:
  GitOps controller. It continuously reconciles cluster state with Git state.

- Namespace `argocd`:
  Isolates Argo CD system components.

- Namespace `dev`:
  Isolates your application workload from system components.

## 3) Files and responsibilities

### `scripts/install.sh`
The bootstrap script. This is the only file you need to run manually.
It installs all required tools (Docker, kubectl, k3d, argocd CLI), creates the K3d cluster, then applies all Kubernetes manifests in order. Without this script the cluster and Argo CD would not exist.

### `confs/namespace.yaml`
A Kubernetes manifest that creates two namespaces: `argocd` and `dev`.
- `argocd`: Argo CD system components (server, repo-server, application-controller, etc.) will live here.
- `dev`: Your application will be deployed here by Argo CD.
Namespaces are applied first so the subsequent installs have somewhere to deploy into.

### `confs/argocd-app.yaml`
A Kubernetes custom resource of kind `Application` (owned by Argo CD).
This is the GitOps contract between Argo CD and your GitHub repository.
It tells Argo CD:
- `repoURL`: which GitHub repository to watch.
- `path`: which folder inside the repo contains Kubernetes manifests (`p3/confs/app`).
- `targetRevision: HEAD`: always sync from the latest commit.
- `destination.namespace: dev`: deploy whatever it finds in that folder into the `dev` namespace.
- `automated.prune: true`: if a resource is removed from Git, delete it from the cluster too.
- `automated.selfHeal: true`: if someone manually changes a resource in the cluster, revert it back to match Git.

### `confs/app/deployment.yaml`
The actual application manifests tracked and deployed by Argo CD. Contains two resources:
- **Deployment**: instructs Kubernetes to run 1 replica of the `wil42/playground` container on port `8888`. Changing the image tag here (e.g. `v1` → `v2`) and pushing to Git is what triggers an automatic version update.
- **Service**: exposes the container inside the cluster under a stable DNS name (`playground.dev.svc.cluster.local`), which is what you port-forward to access the app from your host machine.

## 4) How the install script works (step by step)

When you run `scripts/install.sh`, it does this:
1. Installs Docker, curl, certificates.
2. Enables and starts Docker service.
3. Installs latest stable `kubectl`.
4. Installs `k3d`.
5. Installs `argocd` CLI.
6. Creates a K3d cluster named `iot-cluster` and maps host port `8888`.
7. Writes kubeconfig to `~/.kube/config`.
8. Applies `confs/namespace.yaml`.
9. Installs Argo CD manifests in `argocd` namespace.
10. Waits until `argocd-server` is available.
11. Applies `confs/argocd-app.yaml`.
12. Prints Argo CD admin credentials and access commands.

## 5) Before running (important checks)

Open `confs/argocd-app.yaml` and verify:
- `repoURL` points to your public repository.
- `path` is `p3/confs/app`.

For your project, expected repo URL should be:
- `https://github.com/abboutah/Inception-of-things`

Also verify app image in `confs/app/deployment.yaml`:
- `wil42/playground:v1`

## 6) How to run everything

Run on your Linux VM (inside project root):

```bash
cd p3
chmod +x scripts/install.sh
./scripts/install.sh
```

If the shell session does not immediately get Docker group permissions, run:

```bash
newgrp docker
```

Then rerun the script if needed.

## 7) How to access services

### Argo CD UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open:
- `https://localhost:8080`

Login:
- Username: `admin`
- Password: printed by script (or retrieve with command below)

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo
```

### Application

```bash
kubectl port-forward svc/playground -n dev 8888:8888
```

Test:

```bash
curl http://localhost:8888/
```

Expected response includes current version message (`v1` or `v2`).

## 8) GitOps update demo (defense flow)

This is the required demonstration for evaluation.

1. Change image version in `confs/app/deployment.yaml`:

```bash
sed -i 's/wil42\/playground:v1/wil42\/playground:v2/g' confs/app/deployment.yaml
```

2. Commit and push:

```bash
git add confs/app/deployment.yaml
git commit -m "chore(p3): switch playground image v1 to v2"
git push
```

3. Argo CD auto-syncs (because `automated` sync policy is enabled).

4. Verify new rollout:

```bash
kubectl get pods -n dev
kubectl describe deploy playground -n dev | grep -i image
curl http://localhost:8888/
```

## 9) Verify all required elements

```bash
kubectl get ns
kubectl get pods -n argocd
kubectl get all -n dev
kubectl get applications -n argocd
```

You should see:
- `argocd` and `dev` namespaces,
- Argo CD pods running,
- app resources in `dev`,
- Argo CD Application healthy/synced.

## 10) Common issues and fixes

- Argo CD Application is OutOfSync:
  Check if `repoURL`, `targetRevision`, and `path` in `confs/argocd-app.yaml` are correct.

- ImagePullBackOff:
  Verify image name/tag in `confs/app/deployment.yaml`.

- Cannot connect to Docker daemon:
  Run `newgrp docker` or re-login after adding user to docker group.

- Port already in use (8888 or 8080):
  Stop existing port-forward process or choose another local port.

- Argo CD server not ready in time:
  Check events and pods:

```bash
kubectl get pods -n argocd
kubectl describe pod -n argocd <pod-name>
```

## 11) Why this satisfies the project requirement

- Uses K3d (not Vagrant) for Part 3 cluster.
- Uses Argo CD in dedicated namespace.
- Uses separate `dev` namespace for app.
- Deploys app from public GitHub repository.
- Supports two versions (`v1`, `v2`) through image tags.
- Demonstrates automatic update after Git change.
