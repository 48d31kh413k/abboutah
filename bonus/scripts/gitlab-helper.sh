#!/bin/bash
# Helper script for GitLab + Argo CD integration
set -eu

usage() {
  echo "Usage: $0 <command> [options]"
  echo ""
  echo "Commands:"
  echo "  mirror-repo <github-url> <gitlab-username> <gitlab-password>"
  echo "      Mirror a GitHub repository to your local GitLab"
  echo ""
  echo "  configure-argocd <gitlab-project-url>"
  echo "      Configure Argo CD to sync from a GitLab repository"
  echo ""
  echo "  test-sync"
  echo "      Test the GitOps workflow by bumping the app version"
  echo ""
  echo "  show-status"
  echo "      Display current cluster status"
  exit 1
}

if [[ $# -eq 0 ]]; then
  usage
fi

COMMAND=$1

case $COMMAND in
  mirror-repo)
    if [[ $# -ne 4 ]]; then
      echo "Usage: $0 mirror-repo <github-url> <gitlab-username> <gitlab-password>"
      exit 1
    fi
    GITHUB_URL=$2
    GITLAB_USER=$3
    GITLAB_PASS=$4
    
    echo "[*] Mirroring GitHub repo to GitLab..."
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    git clone --mirror "$GITHUB_URL" repo.git
    cd repo.git
    git push --mirror "https://${GITLAB_USER}:${GITLAB_PASS}@gitlab.local/${GITLAB_USER}/$(basename $GITHUB_URL)"
    
    cd /
    rm -rf "$TEMP_DIR"
    echo "[+] Mirror complete!"
    ;;
    
  configure-argocd)
    if [[ $# -ne 2 ]]; then
      echo "Usage: $0 configure-argocd <gitlab-project-url>"
      exit 1
    fi
    GITLAB_REPO=$2
    
    echo "[*] Configuring Argo CD for GitLab repository..."
    
    # Create temporary app file
    cat > /tmp/argocd-app-temp.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: playground-gitlab
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $GITLAB_REPO
    targetRevision: main
    path: bonus/confs/app
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
    
    kubectl delete app playground-gitlab -n argocd 2>/dev/null || true
    kubectl apply -f /tmp/argocd-app-temp.yaml
    rm /tmp/argocd-app-temp.yaml
    
    echo "[+] Argo CD configured!"
    echo "    Repository: $GITLAB_REPO"
    echo "[*] Waiting for sync..."
    sleep 5
    kubectl get app -n argocd
    ;;
    
  test-sync)
    echo "[*] Testing GitOps sync workflow..."
    echo "[*] This would require cloning the GitLab repo locally and updating it"
    echo "[*] For now, showing current app status:"
    
    echo ""
    echo "=== Argo CD App Status ==="
    kubectl describe app playground-gitlab -n argocd 2>/dev/null || echo "App not configured yet"
    
    echo ""
    echo "=== Deployed Pod ==="
    kubectl get pods -n dev -l app=playground
    
    echo ""
    echo "=== Test Request ==="
    kubectl port-forward svc/playground -n dev 8888:8888 &
    sleep 2
    curl http://localhost:8888/ || echo "Service not ready"
    kill %1 2>/dev/null || true
    ;;
    
  show-status)
    echo "=== K3d Cluster Status ==="
    k3d cluster list
    
    echo ""
    echo "=== Namespaces ==="
    kubectl get ns
    
    echo ""
    echo "=== GitLab ==="
    kubectl get pods -n gitlab
    
    echo ""
    echo "=== Argo CD ==="
    kubectl get pods -n argocd
    
    echo ""
    echo "=== Dev (Application) ==="
    kubectl get pods -n dev
    
    echo ""
    echo "=== Argo CD Applications ==="
    kubectl get app -n argocd
    ;;
    
  *)
    echo "Unknown command: $COMMAND"
    usage
    ;;
esac
