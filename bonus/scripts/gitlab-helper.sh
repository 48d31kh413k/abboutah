#!/bin/bash
# Helper script for GitLab + Argo CD integration
set -eu

usage() {
  echo "Usage: $0 <command> [options]"
  echo ""
  echo "Commands:"
  echo "  mirror-repo <github-url> <gitlab-username> <gitlab-password>"
  echo "      Mirror a GitHub repository to local GitLab (same repo name)"
  echo ""
  echo "  configure-argocd <gitlab-project-url>"
  echo "      Point Argo CD app to GitLab using p3/confs/app manifests"
  echo ""
  echo "  show-status"
  echo "      Show cluster, GitLab and Argo CD status"
  echo ""
  echo "  show-password"
  echo "      Print GitLab initial root password"
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
    REPO_NAME="$(basename "$GITHUB_URL" .git)"
    
    echo "[*] Mirroring GitHub repo to GitLab..."
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    git clone --mirror "$GITHUB_URL" repo.git
    cd repo.git
    git push --mirror "http://${GITLAB_USER}:${GITLAB_PASS}@localhost:8081/${GITLAB_USER}/${REPO_NAME}.git"
    
    cd /
    rm -rf "$TEMP_DIR"
    echo "[+] Mirror complete"
    echo "    GitLab repo URL: http://gitlab-webservice-default.gitlab.svc.cluster.local:8181/${GITLAB_USER}/${REPO_NAME}.git"
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
    path: p3/confs/app
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

  show-password)
    kubectl get secret gitlab-initial-root-password -n gitlab -o jsonpath='{.data.password}' | base64 -d
    echo ""
    ;;
    
  *)
    echo "Unknown command: $COMMAND"
    usage
    ;;
esac
