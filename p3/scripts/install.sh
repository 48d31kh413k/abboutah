#!/bin/bash
# Installation script for K3d cluster with Argo CD and GitOps setup
set -eu  # Exit on error; error on undefined variables

# Get script directory and set configs path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"  # Absolute path to script location
CONFS_DIR="$SCRIPT_DIR/../confs"  # Path to config files directory

# Phase 1: Install system dependencies
echo "[1/4] Install dependencies"
sudo apt-get update -y  # Update package lists
sudo apt-get install -y docker.io curl git  # Install Docker, curl, and git
sudo systemctl enable docker --now  # Enable and start Docker service

# Phase 2: Install Kubernetes tools
echo "[2/4] Install kubectl and k3d"
curl -fsSL -o kubectl https://dl.k8s.io/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl  # Download kubectl
sudo install -m 0755 kubectl /usr/local/bin/  # Install kubectl to PATH
rm -f kubectl  # Clean up kubectl binary
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash  # Install k3d

# Phase 3: Create local Kubernetes cluster
echo "[3/4] Create k3d cluster"
k3d cluster create iot-cluster --port "8888:8888@loadbalancer" 2>/dev/null || true  # Create cluster (ignore if exists)
mkdir -p ~/.kube  # Create kube config directory
k3d kubeconfig get iot-cluster > ~/.kube/config  # Export cluster credentials
export KUBECONFIG=~/.kube/config  # Set kubectl to use this cluster

# Phase 4: Deploy Argo CD and application
echo "[4/4] Deploy Argo CD and app"
kubectl apply -f "$CONFS_DIR/namespace.yaml"  # Create argocd and dev namespaces
kubectl apply --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml -n argocd 2>&1 | grep -v "Warning:" || true  # Install Argo CD (suppress warnings)
kubectl apply -f "$CONFS_DIR/argocd-app.yaml"  # Register GitOps application
sleep 10  # Wait for services to stabilize
kubectl wait --for=condition=available --timeout=120s deployment/argocd-server -n argocd 2>/dev/null || true  # Wait for Argo CD to be ready

# Retrieve Argo CD admin password
ARGOCD_PASS="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo 'N/A')"  # Decode initial password

# Display setup completion summary
echo ""  # Blank line
echo "Done. Argo CD will auto-sync from Git."  # Completion message
echo "Admin: $ARGOCD_PASS"  # Show admin password for Argo CD
echo ""  # Blank line
echo "=== Access from VM ==="
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"  # Command to access Argo CD UI
echo "kubectl port-forward svc/playground -n dev 8888:8888"  # Command to access playground app
echo ""  # Blank line
echo "=== Access from local machine (macOS) ==="
echo "ssh -L 8080:localhost:8080 abboutah@127.0.0.1 -p 2222 -N  # Tunnel for Argo CD"
echo "ssh -L 8888:localhost:8888 abboutah@127.0.0.1 -p 2222 -N  # Tunnel for playground app"
echo ""  # Blank line
echo "Then browse to:"
echo "  Argo CD: http://localhost:8080"
echo "  Playground: http://localhost:8888"