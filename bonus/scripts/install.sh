#!/bin/bash

# Bonus: install local GitLab on top of Part 3
set -eu

GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFS_DIR="$SCRIPT_DIR/../confs"

echo -e "${GREEN}[*] Starting bonus installation (GitLab + existing Part 3 cluster)${RESET}"

echo -e "${GREEN}[1/5] Verify Kubernetes cluster access${RESET}"
if ! kubectl cluster-info &>/dev/null; then
  echo -e "${RED}[!] ERROR: k3d cluster not found!${RESET}"
  echo -e "${RED}[!] Please run Part 3 first.${RESET}"
  exit 1
fi
echo -e "${GREEN}[✓] Cluster is reachable${RESET}"

echo -e "${GREEN}[2/5] Ensure Helm is installed${RESET}"
if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo -e "${GREEN}[3/5] Create gitlab namespace${RESET}"
kubectl apply -f "$CONFS_DIR/namespace.yaml"

echo -e "${GREEN}[4/5] Ensure root password secret exists${RESET}"
if ! kubectl get secret gitlab-initial-root-password -n gitlab >/dev/null 2>&1; then
  kubectl create secret generic gitlab-initial-root-password \
    --from-literal=password="InsecurePassword1!" \
    -n gitlab
fi

echo -e "${GREEN}[5/5] Install or upgrade GitLab Helm release${RESET}"
helm repo add gitlab https://charts.gitlab.io 2>/dev/null || true
helm repo update

# Clean up old release if it exists to avoid schema conflicts
helm delete gitlab -n gitlab 2>/dev/null || true
sleep 2

helm upgrade --install gitlab gitlab/gitlab \
  -n gitlab \
  -f "$CONFS_DIR/gitlab-values.yaml" \
  --timeout 30m \
  --wait

echo ""
echo -e "${GREEN}========================================${RESET}"
echo -e "${GREEN}✓ Bonus Installation Complete${RESET}"
echo -e "${GREEN}========================================${RESET}"
echo ""
echo -e "${GREEN}[✓] Part 3 remains unchanged${RESET}"
echo "  argocd namespace is still running"
echo "  dev namespace app is still running"
echo ""
echo "Check GitLab pods:"
echo "  kubectl get pods -n gitlab"
echo ""
echo "Open GitLab from VM:"
echo "  kubectl port-forward svc/gitlab-webservice-default -n gitlab 8081:8181"
echo "  http://localhost:8081"
echo "  Username: root"
echo "  Password: InsecurePassword1!"
echo ""
echo "Argo CD apps:"
echo "  kubectl get applications -n argocd"
