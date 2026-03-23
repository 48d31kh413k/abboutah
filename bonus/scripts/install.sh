#!/bin/bash
# Installation script for K3d cluster with GitLab and Argo CD (Bonus Part)
set -eu

# Get script directory and set configs path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFS_DIR="$SCRIPT_DIR/../confs"

# Check disk space availability (need at least 10GB for GitLab + k3d)
AVAILABLE_SPACE=$(df /var/lib/docker 2>/dev/null | awk 'NR==2 {print $4}' || df / | awk 'NR==2 {print $4}')
AVAILABLE_GB=$((AVAILABLE_SPACE / 1024 / 1024))

echo "[*] Disk space check: ${AVAILABLE_GB}GB available"
if [ "$AVAILABLE_GB" -lt 15 ]; then
  echo "[!] WARNING: Low disk space detected (${AVAILABLE_GB}GB). GitLab may fail to deploy."
  echo "[!] Recommendation: Free up at least 15GB of disk space."
  echo "[!] You can run: docker system prune -a"
  read -p "Continue anyway? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Phase 1: Install system dependencies
echo "[1/6] Install dependencies"
sudo apt-get update -y
sudo apt-get install -y docker.io curl git wget kubectl
sudo systemctl enable docker --now

# Phase 2: Install Kubernetes tools and Helm
echo "[2/6] Install k3d and helm"
# Install k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Install helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Phase 3: Create local Kubernetes cluster
echo "[3/6] Create k3d cluster"
# Clean up existing cluster and related Docker resources
echo "[*] Cleaning up previous cluster..."
k3d cluster delete iot-cluster 2>/dev/null || true
# Remove all k3d-related containers and volumes to free disk space
docker system prune -a -f 2>/dev/null || true
sleep 3

# Create cluster with sufficient memory and disk space
# Note: k3d doesn't directly control volume size, but we ensure Docker has space
k3d cluster create iot-cluster \
  --port "8888:8888@loadbalancer" \
  --port "8080:8080@loadbalancer" \
  --port "443:443@loadbalancer" \
  --servers-memory 2g \
  --servers 1

mkdir -p ~/.kube
k3d kubeconfig get iot-cluster > ~/.kube/config
export KUBECONFIG=~/.kube/config

# Verify cluster is ready
echo "[*] Waiting for cluster to be ready..."
kubectl cluster-info
kubectl wait --for=condition=Ready nodes --all --timeout=60s 2>/dev/null || true

# Phase 4: Create namespaces
echo "[4/6] Create namespaces (gitlab, argocd, dev)"
kubectl apply -f "$CONFS_DIR/namespace.yaml"

# Phase 5: Install and configure GitLab
echo "[5/6] Install GitLab using Helm"
# Clean up old failed pods before installing
kubectl delete pods --all -n gitlab 2>/dev/null || true
docker system prune -f 2>/dev/null || true

helm repo add gitlab https://charts.gitlab.io
helm repo update

# Install GitLab Community Edition
helm upgrade --install gitlab gitlab/gitlab \
  --namespace gitlab \
  --values "$CONFS_DIR/gitlab-values.yaml" \
  --timeout 15m \
  --wait 2>&1 | grep -v "Warning:" || true

# Wait for GitLab to be ready
echo "Waiting for GitLab to initialize (this may take a few minutes)..."
echo "[*] Waiting for webservice pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=webservice -n gitlab --timeout=600s 2>/dev/null || {
  echo "[!] Warning: Pods not ready after 10 minutes. Checking status..."
  kubectl get pods -n gitlab -o wide
}

# Phase 6: Install Argo CD
echo "[6/6] Deploy Argo CD"
kubectl apply --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml -n argocd 2>&1 | grep -v "Warning:" || true

# Wait for Argo CD to be ready
sleep 10
kubectl wait --for=condition=available --timeout=120s deployment/argocd-server -n argocd 2>/dev/null || true

# Check for disk pressure issues
echo "[*] Checking cluster health..."
if kubectl get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="DiskPressure")].status}' | grep -q "True"; then
  echo "[!] WARNING: Cluster is experiencing DiskPressure!"
  echo "[!] Some pods may not start. Try freeing disk space:"
  echo "[!]   docker system prune -a"
  echo "[!]   k3d cluster delete iot-cluster && bash install.sh"
fi

# Retrieve passwords
GITLAB_PASS="$(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo 'N/A')"
ARGOCD_PASS="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo 'N/A')"

# Display setup completion summary
echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "=== GitLab Access (VM) ==="
echo "kubectl port-forward svc/gitlab-webservice -n gitlab 443:8181 &"
echo "https://localhost"
echo "Username: root"
echo "Password: $GITLAB_PASS"
echo ""
echo "=== Argo CD Access (VM) ==="
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443 &"
echo "Username: admin"
echo "Password: $ARGOCD_PASS"
echo ""
echo "=== Playground App (VM) ==="
echo "kubectl port-forward svc/playground -n dev 8888:8888 &"
echo ""
echo "=== SSH Tunnels for Local Machine (macOS) ==="
echo "ssh -L 8443:localhost:443 root@127.0.0.1 -p 2222 -N  # GitLab"
echo "ssh -L 8080:localhost:8080 root@127.0.0.1 -p 2222 -N  # Argo CD"
echo "ssh -L 8888:localhost:8888 root@127.0.0.1 -p 2222 -N  # Playground"
echo ""
echo "Then browse to:"
echo "  GitLab: https://localhost:8443"
echo "  Argo CD: http://localhost:8080"
echo "  Playground: http://localhost:8888"
echo "=========================================="
