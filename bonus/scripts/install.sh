#!/bin/bash

# Bonus: Install GitLab only (assumes Part 3 is already running)
set -eu

GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFS_DIR="$SCRIPT_DIR/../confs"

echo -e "${GREEN}[*] Starting Bonus: GitLab Installation...${RESET}"

# =============================================================================
# Check if cluster is running
# =============================================================================
echo -e "${GREEN}[1/3] Verify k3d cluster is running${RESET}"
if ! kubectl cluster-info &>/dev/null; then
  echo -e "${RED}[!] ERROR: k3d cluster not found!${RESET}"
  echo -e "${RED}[!] Please run Part 3 first.${RESET}"
  exit 1
fi
echo -e "${GREEN}[✓] Cluster is running${RESET}"

# =============================================================================
# Install Helm (if needed)
# =============================================================================
echo -e "${GREEN}[2/3] Install Helm${RESET}"
which helm &>/dev/null || curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash >/dev/null 2>&1

# =============================================================================
# Install GitLab
# =============================================================================
echo -e "${GREEN}[3/3] Deploy GitLab${RESET}"

# Create gitlab namespace
kubectl create namespace gitlab 2>/dev/null || true

# Add GitLab Helm repo
helm repo add gitlab https://charts.gitlab.io 2>/dev/null || true
helm repo update gitlab 2>/dev/null || true

echo -e "${YELLOW}[!] GitLab installing (15-20 mins in background)${RESET}"
helm upgrade --install gitlab gitlab/gitlab \
  -n gitlab \
  -f "$CONFS_DIR/gitlab-values.yaml" \
  --timeout 20m \
  --wait=false &>/dev/null &

# Remove upgrade-check jobs that block deployment (they fail anyway on fresh installs)
# Run in a loop to keep deleting them as they get recreated
(
  for i in {1..30}; do
    sleep 2
    kubectl delete job -n gitlab -l app.kubernetes.io/instance=gitlab-upgrade-check 2>/dev/null || true
    kubectl delete job -n gitlab --field-selector status.successful=0 -l app.kubernetes.io/name=gitlab-upgrade-check 2>/dev/null || true
  done
) &

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${GREEN}========================================${RESET}"
echo -e "${GREEN}✓ Bonus Installation Started!${RESET}"
echo -e "${GREEN}========================================${RESET}"
echo ""

echo -e "${GREEN}[✓] Part 3 Services (Already Running)${RESET}"
echo "  ✓ Argo CD: http://localhost:8080"
echo "  ✓ Playground App: http://localhost:8888"
echo ""

echo -e "${YELLOW}[!] COMING SOON - GitLab (15-20 mins)${RESET}"
echo "  Check status: kubectl get pods -n gitlab"
echo "  When ready:"
echo "  kubectl port-forward svc/gitlab-webservice-default -n gitlab 80:8181 &"
echo "  http://localhost (or http://gitlab.k3d.gitlab.com)"
echo "  Username: root"
echo ""

echo -e "${GREEN}[→] Monitor GitLab initialization:${RESET}"
echo "  kubectl logs -n gitlab -f deployment/gitlab-webservice-default"
echo ""

echo -e "${GREEN}========================================${RESET}"
