echo "[*] Cleaning existing GitLab installation..."  # Start cleanup

helm uninstall gitlab -n gitlab 2>/dev/null || true  # Uninstall GitLab Helm release

kubectl delete namespace gitlab --wait=true 2>/dev/null || true  # Delete GitLab namespace and all resources

kubectl create namespace gitlab  # Recreate namespace

kubectl create secret generic gitlab-initial-root-password \
  --from-literal=password="InsecurePassword1!" \
  -n gitlab  # Recreate root password secret

echo "[✓] Clean slate ready"  # Done