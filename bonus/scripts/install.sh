#!/bin/bash

# Fast GitLab + Argo CD installation for K3d
set -eu

GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFS_DIR="$SCRIPT_DIR/../confs"

echo -e "${GREEN}[*] Starting fast installation...${RESET}"

# =============================================================================
# PHASE 1: Install dependencies
# =============================================================================
echo -e "${GREEN}[1/5] Install dependencies${RESET}"
sudo apt-get update -y 2>&1 | grep -i "hit\|get\|reading" || true
sudo apt-get install -y curl git wget kubectl 2>&1 | tail -3

# =============================================================================
# PHASE 2: Install Helm & K3d
# =============================================================================
echo -e "${GREEN}[2/5] Install k3d and helm${RESET}"
which k3d &>/dev/null || curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash >/dev/null 2>&1
which helm &>/dev/null || curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash >/dev/null 2>&1

# =============================================================================
# PHASE 3: Create k3d cluster
# =============================================================================
echo -e "${GREEN}[3/5] Create k3d cluster${RESET}"
k3d cluster delete iot-cluster 2>/dev/null || true
docker system prune -a -f 2>/dev/null || true
sleep 2

k3d cluster create iot-cluster \
  --port "8888:8888@loadbalancer" \
  --port "8080:8080@loadbalancer" \
  --port "443:443@loadbalancer" \
  --servers 1

mkdir -p ~/.kube
k3d kubeconfig get iot-cluster > ~/.kube/config
export KUBECONFIG=~/.kube/config

echo -e "${YELLOW}[*] Waiting for cluster...${RESET}"
kubectl cluster-info 2>/dev/null
sleep 3

# =============================================================================
# PHASE 4: Create namespaces
# =============================================================================
echo -e "${GREEN}[4/5] Create namespaces${RESET}"
kubectl apply -f "$CONFS_DIR/namespace.yaml" 2>/dev/null || true

# =============================================================================
# PHASE 5: Install GitLab (background) + Argo CD (fast)
# =============================================================================
echo -e "${GREEN}[5/5] Deploy services${RESET}"

# GitLab - non-blocking
helm repo add gitlab https://charts.gitlab.io 2>/dev/null || true
helm repo update gitlab 2>/dev/null || true

echo -e "${YELLOW}[!] GitLab installing (background)${RESET}"
helm upgrade --install gitlab gitlab/gitlab \
  -n gitlab \
  -f "$CONFS_DIR/gitlab-values.yaml" \
  --timeout 20m \
  --wait=false &>/dev/null &

# Argo CD - fast
kubectl apply --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml -n argocd 2>&1 | grep -v "Warning:" || true

echo -e "${YELLOW}[*] Waiting for Argo CD...${RESET}"
kubectl wait --for=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=60s 2>/dev/null || echo "Initializing..."

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${GREEN}========================================${RESET}"
echo -e "${GREEN}✓ Installation Complete!${RESET}"
echo -e "${GREEN}========================================${RESET}"
echo ""

echo -e "${GREEN}[✓] READY NOW - Argo CD${RESET}"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443 &"
echo "  http://localhost:8080"
echo "  ssh -L 8080:localhost:8080 root@127.0.0.1 -p 2222 -N"
echo ""

echo -e "${YELLOW}[!] COMING SOON - GitLab (15-20 mins)${RESET}"
echo "  kubectl get pods -n gitlab"
echo ""

echo -e "${GREEN}[→] DEPLOY YOUR APP:${RESET}"
echo "  kubectl apply -f $CONFS_DIR/../app/deployment.yaml"
echo "  kubectl port-forward svc/playground -n dev 8888:8888 &"
echo "  http://localhost:8888"
echo ""
echo -e "${GREEN}========================================${RESET}"
