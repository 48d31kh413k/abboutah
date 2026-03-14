#!/usr/bin/env bash
# FILE: install.sh
# PURPOSE: Bootstrap Docker, K3d, kubectl, and Argo CD, then register the GitOps application.
# USAGE: Run from p3/ with REPO_URL=https://github.com/LOGIN/REPO ./scripts/install.sh
# NOTES: Designed for Debian or Ubuntu VMs; safe to run multiple times.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFS_DIR="$SCRIPT_DIR/../confs"
CLUSTER_NAME="iot"
ARGOCD_MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Install only the OS packages that are missing so the script stays idempotent.
apt_install() {
  local missing=()
  for package in "$@"; do
    dpkg -s "$package" >/dev/null 2>&1 || missing+=("$package")
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    sudo apt-get update
    sudo apt-get install -y "${missing[@]}"
  fi
}

# Install kubectl only when the binary is absent.
install_kubectl() {
  command -v kubectl >/dev/null 2>&1 && return
  local version
  version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  curl -fsSL -o /tmp/kubectl "https://dl.k8s.io/release/${version}/bin/linux/amd64/kubectl"
  sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
  rm -f /tmp/kubectl
}

# Install k3d only when it is not already available.
install_k3d() {
  command -v k3d >/dev/null 2>&1 && return
  curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
}

# Normalize the repository URL so Argo CD always receives an HTTPS GitHub URL.
resolve_repo_url() {
  local repo_url="${REPO_URL:-$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || true)}"
  repo_url="${repo_url:-https://github.com/48d31kh413k/Inception-of-things}"

  if [[ "$repo_url" == git@github.com:* ]]; then
    repo_url="https://github.com/${repo_url#git@github.com:}"
  fi

  printf '%s\n' "${repo_url%.git}"
}

# Create the cluster once and refresh kubeconfig on every run.
ensure_cluster() {
  local k3d_cmd=(k3d)

  if ! docker info >/dev/null 2>&1; then
    k3d_cmd=(sudo k3d)
  fi

  if ! "${k3d_cmd[@]}" cluster list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$CLUSTER_NAME"; then
    "${k3d_cmd[@]}" cluster create "$CLUSTER_NAME" --port "8888:8888@loadbalancer"
  fi

  mkdir -p "$HOME/.kube"
  "${k3d_cmd[@]}" kubeconfig get "$CLUSTER_NAME" > "$HOME/.kube/config"
  export KUBECONFIG="$HOME/.kube/config"
}

# Create namespaces explicitly because Argo CD and the workload live in separate scopes.
ensure_namespaces() {
  kubectl get namespace argocd >/dev/null 2>&1 || kubectl create namespace argocd
  kubectl get namespace dev >/dev/null 2>&1 || kubectl create namespace dev
}

# Install Argo CD once, then always wait for the API server deployment to be ready.
ensure_argocd() {
  if ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
    kubectl apply -n argocd -f "$ARGOCD_MANIFEST_URL"
  fi

  kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
}

# Apply the Application manifest after injecting the repo URL placeholder.
apply_argocd_application() {
  local repo_url tmp_manifest
  repo_url="$(resolve_repo_url)"
  tmp_manifest="$(mktemp)"
  sed "s|https://github.com/48d31kh413k/Inception-of-things|$repo_url|g" "$CONFS_DIR/argocd-app.yaml" > "$tmp_manifest"
  kubectl apply -f "$tmp_manifest"
  rm -f "$tmp_manifest"
}

# Docker is required for k3d, so the service is installed and started before cluster work begins.
apt_install docker.io curl ca-certificates
sudo systemctl enable --now docker >/dev/null 2>&1

install_kubectl
install_k3d
ensure_cluster
ensure_namespaces
ensure_argocd
apply_argocd_application

kubectl get applications.argoproj.io playground -n argocd >/dev/null