#!/bin/bash
set -eux

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFS_DIR="$SCRIPT_DIR/../confs"
CLUSTER_NAME="iot-cluster"

# ─── Install Docker ───────────────────────────────────────────────────────────
sudo apt-get update -y
sudo apt-get install -y docker.io curl ca-certificates

sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker "$USER"

# ─── Install kubectl ─────────────────────────────────────────────────────────
KUBECTL_VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# ─── Install k3d ─────────────────────────────────────────────────────────────
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# ─── Install ArgoCD CLI ───────────────────────────────────────────────────────
ARGOCD_VERSION="$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | grep '"tag_name"' | cut -d'"' -f4)"
curl -sSL -o argocd "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64"
sudo install -m 755 argocd /usr/local/bin/argocd
rm argocd

# ─── Create K3d cluster ───────────────────────────────────────────────────────
# Run k3d via the docker group without needing to log out/in
if ! groups | grep -q docker; then
  sudo k3d cluster create "$CLUSTER_NAME" --port "8888:8888@loadbalancer"
  mkdir -p ~/.kube
  sudo k3d kubeconfig get "$CLUSTER_NAME" | sudo tee ~/.kube/config > /dev/null
  sudo chown "$USER":"$USER" ~/.kube/config
else
  k3d cluster create "$CLUSTER_NAME" --port "8888:8888@loadbalancer"
  mkdir -p ~/.kube
  k3d kubeconfig get "$CLUSTER_NAME" > ~/.kube/config
fi

export KUBECONFIG=~/.kube/config

# ─── Create namespaces ────────────────────────────────────────────────────────
kubectl apply -f "$CONFS_DIR/namespace.yaml"

# ─── Install Argo CD ─────────────────────────────────────────────────────────
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD server to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# ─── Apply Argo CD Application ────────────────────────────────────────────────
kubectl apply -f "$CONFS_DIR/argocd-app.yaml"

# ─── Print summary ───────────────────────────────────────────────────────────
ARGOCD_PASS="$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)"

echo ""
echo "========================================"
echo "  Argo CD is ready!"
echo "  Username : admin"
echo "  Password : $ARGOCD_PASS"
echo "========================================"
echo ""
echo "Access the Argo CD UI:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Then open: https://localhost:8080"
echo ""
echo "Access the playground app:"
echo "  kubectl port-forward svc/playground -n dev 8888:8888"
echo "  Then open: http://localhost:8888"