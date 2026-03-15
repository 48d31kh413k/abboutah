#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFS_DIR="$SCRIPT_DIR/../confs"

echo "[1/4] Install dependencies"
sudo apt-get update -y
sudo apt-get install -y docker.io curl git
sudo systemctl enable docker --now

echo "[2/4] Install kubectl and k3d"
curl -fsSL -o kubectl https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl
sudo install -m 0755 kubectl /usr/local/bin/
rm -f kubectl
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo "[3/4] Create k3d cluster"
k3d cluster create iot-cluster --port "8888:8888@loadbalancer" 2>/dev/null || true
mkdir -p ~/.kube
k3d kubeconfig get iot-cluster > ~/.kube/config
export KUBECONFIG=~/.kube/config

echo "[4/4] Deploy Argo CD and app"
kubectl apply -f "$CONFS_DIR/namespace.yaml"
kubectl apply --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml -n argocd 2>&1 | grep -v "Warning:" || true
kubectl apply -f "$CONFS_DIR/argocd-app.yaml"
sleep 10
kubectl wait --for=condition=available --timeout=120s deployment/argocd-server -n argocd 2>/dev/null || true

ARGOCD_PASS="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo 'N/A')"

echo ""
echo "Done. Argo CD will auto-sync from Git."
echo "Admin: $ARGOCD_PASS"
echo ""
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "kubectl port-forward svc/playground -n dev 8888:8888"