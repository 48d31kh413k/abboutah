#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFS_DIR="$SCRIPT_DIR/../confs"

CLUSTER_NAME="${CLUSTER_NAME:-iot-cluster}"
REPO_URL="https://github.com/48d31kh413k/Inception-of-things"
TARGET_REVISION="main"

echo "[1/8] Install dependencies"
sudo apt-get update -y
sudo apt-get install -y docker.io curl ca-certificates git
sudo systemctl enable docker --now

echo "[2/8] Install kubectl"
KUBECTL_VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
curl -fsSL -o kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
sudo install -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

echo "[3/8] Install k3d"
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo "[4/8] Create or reuse cluster: $CLUSTER_NAME"
if ! k3d cluster list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$CLUSTER_NAME"; then
  k3d cluster create "$CLUSTER_NAME" --port "8888:8888@loadbalancer"
else
  echo "Cluster already exists, reusing it"
fi

mkdir -p ~/.kube
k3d kubeconfig get "$CLUSTER_NAME" > ~/.kube/config
export KUBECONFIG=~/.kube/config

echo "[5/8] Validate Git source"
echo "Repo: $REPO_URL"
echo "Revision: $TARGET_REVISION"
git ls-remote "$REPO_URL" HEAD >/dev/null
git ls-remote "$REPO_URL" "$TARGET_REVISION" | grep -q .

echo "[6/8] Install Argo CD"
kubectl apply -f "$CONFS_DIR/namespace.yaml"
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-application-controller -n argocd

echo "[7/8] Apply Argo CD Application"
kubectl apply -f "$CONFS_DIR/argocd-app.yaml"

echo "[8/8] Force sync and wait"
kubectl annotate application playground -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl patch application playground -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}'
kubectl wait --for=jsonpath='{.status.health.status}'=Healthy --timeout=300s application/playground -n argocd
kubectl rollout status deployment/playground -n dev --timeout=180s

ARGOCD_PASS="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"

echo ""
echo "Argo CD ready"
echo "User: admin"
echo "Pass: $ARGOCD_PASS"
echo ""
echo "Open Argo CD UI"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "https://localhost:8080"
echo ""
echo "Open playground app"
echo "kubectl port-forward svc/playground -n dev 8888:8888"
echo "http://localhost:8888"