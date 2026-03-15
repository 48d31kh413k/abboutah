#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFS_DIR="$SCRIPT_DIR/../confs"

CLUSTER_NAME="${CLUSTER_NAME:-iot-cluster}"

echo "[1/5] Install dependencies"
sudo apt-get update -y
sudo apt-get install -y docker.io curl ca-certificates git
sudo systemctl enable docker --now

echo "[2/5] Install kubectl"
KUBECTL_VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
curl -fsSL -o kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
sudo install -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

echo "[3/5] Install k3d and create cluster"
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
if ! k3d cluster list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$CLUSTER_NAME"; then
  k3d cluster create "$CLUSTER_NAME" --port "8888:8888@loadbalancer"
else
  echo "Cluster already exists, reusing it"
fi

mkdir -p ~/.kube
k3d kubeconfig get "$CLUSTER_NAME" > ~/.kube/config
export KUBECONFIG=~/.kube/config

echo "[4/5] Install Argo CD"
kubectl apply -f "$CONFS_DIR/namespace.yaml"
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo "[5/5] Apply Argo CD app"
kubectl apply -f "$CONFS_DIR/argocd-app.yaml"

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