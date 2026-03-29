#!/bin/bash
# Installation script for K3d cluster with Argo CD and GitOps setup  
set -eu  # Exit if any command fails or if an undefined variable is used

# Get script directory and set configs path  
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"  # Get the directory where this script is located
CONFS_DIR="$SCRIPT_DIR/../confs"  # Set the path to the configuration files

# Phase 1: Install system dependencies 
echo "[1/4] Install dependencies"
sudo apt-get update -y  # Refresh the list of available packages
sudo apt-get install -y docker.io curl git  # Install Docker, curl, and git packages
sudo systemctl enable docker --now  # Start Docker and enable it to run at boot

# Phase 2: Install Kubernetes tools  
echo "[2/4] Install kubectl and k3d"
curl -fsSL -o kubectl https://dl.k8s.io/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl  # Download the latest kubectl binary
sudo install -m 0755 kubectl /usr/local/bin/  # Move kubectl to a directory in the system PATH
rm -f kubectl  # Remove the downloaded kubectl file
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash  # Download and run the k3d installer script

# Phase 3: Create local Kubernetes cluster  
echo "[3/4] Create k3d cluster"
k3d cluster create iot-cluster --port "8888:8888@loadbalancer" 2>/dev/null || true  # Create a k3d cluster or skip if it already exists
mkdir -p ~/.kube  # Make sure the kube config directory exists
k3d kubeconfig get iot-cluster > ~/.kube/config  # Save the kubeconfig for the new cluster
export KUBECONFIG=~/.kube/config  # Set the KUBECONFIG environment variable

# Phase 4: Deploy Argo CD and application 
echo "[4/4] Deploy Argo CD and app"
kubectl apply -f "$CONFS_DIR/namespace.yaml"  # Apply namespace definitions for argocd and dev
kubectl apply --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml -n argocd 2>&1 | grep -v "Warning:" || true  # Install Argo CD in the argocd namespace, ignoring warnings
kubectl apply -f "$CONFS_DIR/argocd-app.yaml"  # Apply the Argo CD application manifest
sleep 10  # Pause to allow services to start
kubectl wait --for=condition=available --timeout=120s deployment/argocd-server -n argocd 2>/dev/null || true  # Wait until the Argo CD server deployment is available

# Retrieve Argo CD admin password
ARGOCD_PASS="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo 'N/A')"  # Retrieve and decode the initial Argo CD admin password

# Display setup completion summary
echo ""  # Blank line
echo "Done. Argo CD will auto-sync from Git."  # Inform the user that setup is complete and GitOps is active
echo "Admin: $ARGOCD_PASS"  # Display the Argo CD admin password
echo ""  # Blank line
echo "=== Access from VM ==="
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"  # Command to forward local port 8080 to Argo CD UI
echo "kubectl port-forward svc/playground -n dev 8888:8888"  # Command to forward local port 8888 to the playground app
echo ""  # Blank line
echo "=== Access from local machine (macOS) ==="
echo "ssh -L 8080:localhost:8080 abboutah@127.0.0.1 -p 2222 -N  # SSH tunnel command for Argo CD UI access from local machine
echo "ssh -L 8888:localhost:8888 abboutah@127.0.0.1 -p 2222 -N  # SSH tunnel command for playground app access from local machine
echo ""  # Blank line
echo "Then browse to:"
echo "  Argo CD: http://localhost:8080"
echo "  Playground: http://localhost:8888"