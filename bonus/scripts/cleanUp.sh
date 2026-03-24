echo "[*] Cleaning existing GitLab installation..."

# Uninstall Helm release (ignore if not installed)
helm uninstall gitlab -n gitlab 2>/dev/null || true

# Delete namespace completely (this removes DB, secrets, everything)
kubectl delete namespace gitlab --wait=true 2>/dev/null || true

# Recreate namespace
kubectl create namespace gitlab

# Recreate root password secret
kubectl create secret generic gitlab-initial-root-password \
  --from-literal=password="InsecurePassword1!" \
  -n gitlab

echo "[✓] Clean slate ready"