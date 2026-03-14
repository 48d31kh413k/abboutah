# Part 3: K3d + Argo CD

Part 3 implements a minimal GitOps flow on a local K3d cluster.

## Structure

```text
p3/
├── scripts/
│   └── install.sh
└── confs/
    ├── argocd-app.yaml
    └── deployment.yaml
```

## Purpose

- `scripts/install.sh` installs the local prerequisites, creates the cluster, installs Argo CD, creates the `argocd` and `dev` namespaces, and registers the Argo CD Application.
- `confs/argocd-app.yaml` tells Argo CD which public GitHub repository to watch and where to deploy the manifests.
- `confs/deployment.yaml` defines the `wil42/playground` workload and service in namespace `dev`.

## Run

```bash
cd p3
chmod +x scripts/install.sh
REPO_URL=https://github.com/LOGIN/REPO ./scripts/install.sh
```

## Verify

```bash
kubectl get ns
kubectl get applications -n argocd
kubectl get all -n dev
kubectl port-forward svc/playground -n dev 8888:8888
curl http://localhost:8888/
```

## Update Demo

Change the image tag in `confs/deployment.yaml` from `v1` to `v2`, commit, and push. Argo CD detects the Git change and reconciles the `dev` namespace automatically because automated sync, prune, and self-heal are enabled.
