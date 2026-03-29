#!/bin/bash

# Install local GitLab on top of Part 3
set -eu  # Exit on error and treat unset variables as errors

GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"  # Script directory
CONFS_DIR="$SCRIPT_DIR/../confs"  # Configs directory

echo -e "${GREEN}[*] Starting bonus installation (GitLab + existing Part 3 cluster)${RESET}"  # Start message

echo -e "${GREEN}[1/5] Verify Kubernetes cluster access${RESET}"  # Step 1: Check cluster
if ! kubectl cluster-info &>/dev/null; then
  echo -e "${RED}[!] ERROR: k3d cluster not found!${RESET}"
  echo -e "${RED}[!] Please run Part 3 first.${RESET}"
  exit 1
fi  # Exit if cluster is not found
echo -e "${GREEN}[✓] Cluster is reachable${RESET}"  # Cluster OK

echo -e "${GREEN}[2/5] Ensure Helm is installed${RESET}"  # Step 2: Check Helm
if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi  # Install Helm if missing

echo -e "${GREEN}[3/5] Create gitlab namespace${RESET}"  # Step 3: Namespace
kubectl apply -f "$CONFS_DIR/namespace.yaml"  # Create namespace

echo -e "${GREEN}[4/5] Ensure root password secret exists${RESET}"  # Step 4: Secret
if ! kubectl get secret gitlab-initial-root-password -n gitlab >/dev/null 2>&1; then
  kubectl create secret generic gitlab-initial-root-password \
    --from-literal=password="InsecurePassword1!" \
    -n gitlab
fi  # Create secret if missing

echo -e "${GREEN}[5/5] Install or upgrade GitLab Helm release${RESET}"  # Step 5: Install GitLab
helm repo add gitlab https://charts.gitlab.io 2>/dev/null || true  # Add GitLab repo
helm repo update  # Update repos

helm upgrade --install gitlab gitlab/gitlab \
  -n gitlab \
  -f "$CONFS_DIR/gitlab-values.yaml" \
  --timeout 30m \
  --wait  # Install or upgrade GitLab

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
