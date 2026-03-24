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
# Optimize resources: scale down Part 3 Argo CD
# =============================================================================
echo -e "${GREEN}[3/3] Optimize cluster resources & Deploy GitLab${RESET}"

echo -e "${YELLOW}[!] Scaling down Argo CD to free resources...${RESET}"
kubectl scale deployment argocd-server -n argocd --replicas=0 2>/dev/null || true
kubectl scale deployment argocd-application-controller -n argocd --replicas=0 2>/dev/null || true
kubectl scale deployment argocd-repo-server -n argocd --replicas=0 2>/dev/null || true
kubectl scale deployment argocd-dex-server -n argocd --replicas=0 2>/dev/null || true
kubectl scale deployment argocd-redis -n argocd --replicas=0 2>/dev/null || true
sleep 5

# Create gitlab namespace
kubectl create namespace gitlab 2>/dev/null || true

# Pre-create ALL required secrets to avoid mount failures
kubectl create secret generic gitlab-initial-root-password \
  --from-literal=password="InsecurePassword1!" \
  -n gitlab 2>/dev/null || true

kubectl create secret generic gitlab-registry-database-password \
  --from-literal=password="registrysecret" \
  -n gitlab 2>/dev/null || true

kubectl create secret generic gitlab-rails-secret \
  --from-literal=secrets.yml="default:\n  secret_key_base: thisisasecretkey1234567890\n" \
  -n gitlab 2>/dev/null || true

kubectl create secret generic gitlab-gitaly-secret \
  --from-literal=token="gitalysecret1234567890" \
  -n gitlab 2>/dev/null || true

kubectl create secret generic gitlab-redis-secret \
  --from-literal=redis-password="redissecret" \
  -n gitlab 2>/dev/null || true

kubectl create secret generic gitlab-postgresql-password \
  --from-literal=postgresql-password="postgressecret" \
  --from-literal=postgresql-postgres-password="postgressecret" \
  -n gitlab 2>/dev/null || true

kubectl create secret generic gitlab-minio-secret \
  --from-literal=accesskey="minioadmin" \
  --from-literal=secretkey="minioadmin123" \
  -n gitlab 2>/dev/null || true

kubectl create secret generic gitlab-gitlab-runner-secret \
  --from-literal=runner-registration-token="runnersecret" \
  -n gitlab 2>/dev/null || true

# Clean up any leftover upgrade-check jobs from previous runs
kubectl delete job -n gitlab --all 2>/dev/null || true

# Add GitLab Helm repo
helm repo add gitlab https://charts.gitlab.io 2>/dev/null || true
helm repo update gitlab 2>/dev/null || true

echo -e "${YELLOW}[!] GitLab installing (15-20 mins in background)${RESET}"
helm upgrade --install gitlab gitlab/gitlab \
  -n gitlab \
  -f "$CONFS_DIR/gitlab-values.yaml" \
  --timeout 20m \
  --wait=false \
  --no-hooks &>/dev/null

# Delete broken webservice pods and stuck migrations
sleep 5
kubectl delete pod -n gitlab -l app.kubernetes.io/name=gitlab-webservice --grace-period=0 --force 2>/dev/null || true
kubectl delete job -n gitlab -l app.kubernetes.io/name=gitlab-migrations --grace-period=0 --force 2>/dev/null || true

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${GREEN}========================================${RESET}"
echo -e "${GREEN}✓ Bonus Installation Started!${RESET}"
echo -e "${GREEN}========================================${RESET}"
echo ""

echo -e "${GREEN}[✓] Part 3 Services (Temporarily Scaled Down)${RESET}"
echo "  ⊘ Argo CD: Scaled to 0 replicas (will restart after bonus)"
echo "  ⊘ Playground App: Still running but isolated"
echo ""

echo -e "${YELLOW}[!] DEPLOYING - GitLab (15-20 mins)${RESET}"
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
echo -e "${GREEN}[→] After GitLab is Ready (Optional)${RESET}"
echo -e "${GREEN}========================================${RESET}"
echo -e "${YELLOW}To restart Argo CD (after GitLab is stable):${RESET}"
echo "  kubectl scale deployment -n argocd --all --replicas=1"
echo ""
