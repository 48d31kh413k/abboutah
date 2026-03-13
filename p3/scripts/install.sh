#!/bin/bash
set -eux

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFS_DIR="$SCRIPT_DIR/../confs"
CLUSTER_NAME="iot-cluster"

# ─── Install Docker ───────────────────────────────────────────────────────────
sudo apt-get update -y
sudo apt-get install -y docker.io curl ca-certificates git

sudo systemctl enable docker
if ! sudo systemctl is-active --quiet docker; then
  sudo systemctl start docker
fi
if ! id -nG "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER"
fi

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
  if sudo k3d cluster list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$CLUSTER_NAME"; then
    echo "k3d cluster '$CLUSTER_NAME' already exists, reusing it"
  else
    sudo k3d cluster create "$CLUSTER_NAME" --port "8888:8888@loadbalancer"
  fi
  mkdir -p ~/.kube
  sudo k3d kubeconfig get "$CLUSTER_NAME" | sudo tee ~/.kube/config > /dev/null
  sudo chown "$USER":"$USER" ~/.kube/config
else
  if k3d cluster list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$CLUSTER_NAME"; then
    echo "k3d cluster '$CLUSTER_NAME' already exists, reusing it"
  else
    k3d cluster create "$CLUSTER_NAME" --port "8888:8888@loadbalancer"
  fi
  mkdir -p ~/.kube
  k3d kubeconfig get "$CLUSTER_NAME" > ~/.kube/config
fi

export KUBECONFIG=~/.kube/config

# ─── Resolve and validate Git repository URL for Argo CD ─────────────────────
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEFAULT_REPO_URL="$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || true)"
REPO_URL="${REPO_URL:-$DEFAULT_REPO_URL}"

if [[ -z "$REPO_URL" ]]; then
  REPO_URL="https://github.com/abboutah/Inception-of-things"
fi

# Convert SSH GitHub remotes to HTTPS for Argo CD repo-server access
if [[ "$REPO_URL" == git@github.com:* ]]; then
  REPO_URL="https://github.com/${REPO_URL#git@github.com:}"
fi
REPO_URL="${REPO_URL%.git}"

echo "Using Argo CD repo URL: $REPO_URL"
if ! git ls-remote "$REPO_URL" HEAD >/dev/null 2>&1; then
  echo "ERROR: Argo CD cannot access repository: $REPO_URL"
  echo "Set a public repo URL and rerun, for example:"
  echo "  REPO_URL=https://github.com/<your-login>/Inception-of-things ./scripts/install.sh"
  exit 1
fi

# ─── Create namespaces ────────────────────────────────────────────────────────
kubectl apply -f "$CONFS_DIR/namespace.yaml"

# ─── Install Argo CD ─────────────────────────────────────────────────────────
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD server to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# ─── Apply Argo CD Application ────────────────────────────────────────────────
TMP_APP_MANIFEST="$(mktemp)"
sed "s|__REPO_URL__|$REPO_URL|g" "$CONFS_DIR/argocd-app.yaml" > "$TMP_APP_MANIFEST"
kubectl apply -f "$TMP_APP_MANIFEST"
rm -f "$TMP_APP_MANIFEST"

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