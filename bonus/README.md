# Bonus Part: Simple GitLab Integration (on top of Part 3)

This bonus keeps Part 3 exactly as-is and only adds a local GitLab instance in a dedicated `gitlab` namespace.

## Goal

- Keep `argocd` and `dev` namespaces from Part 3 working
- Add a third namespace: `gitlab`
- Run a local GitLab (latest Helm chart)
- Point Argo CD to a GitLab repository and keep GitOps flow

## Files

- `confs/namespace.yaml`: creates `gitlab` namespace
- `confs/gitlab-values.yaml`: minimal Helm values for local usage
- `scripts/install.sh`: simple installer, no scaling down of Argo CD
- `scripts/gitlab-helper.sh`: helper for mirror/config/status

## Install

Run inside the VM where Part 3 is already running:

```bash
cd ~/Desktop/Inception-of-things/bonus/scripts
chmod +x install.sh
./install.sh
```

The script:

1. Validates cluster access
2. Installs Helm if missing
3. Creates `gitlab` namespace
4. Creates initial root password secret
5. Installs/updates GitLab chart

## Access GitLab

From VM:

```bash
kubectl port-forward svc/gitlab-webservice-default -n gitlab 8081:8181
```

Then open `http://localhost:8081`.

- User: `root`
- Password: `InsecurePassword1!`

You can also print the password with:

```bash
./gitlab-helper.sh show-password
```

## Wire Argo CD to GitLab

1. Create a project in local GitLab (for example `inception-of-things`).
2. Mirror your GitHub repo to GitLab:

```bash
./gitlab-helper.sh mirror-repo https://github.com/<you>/<repo>.git root <password>
```

3. Configure Argo CD to use GitLab:

```bash
./gitlab-helper.sh configure-argocd http://localhost:8081/root/<repo>.git
```

This Argo CD app syncs from `p3/confs/app`, so your Part 3 app version switch (`v1` -> `v2`) remains the same workflow.

## Verify

```bash
./gitlab-helper.sh show-status
kubectl get ns
kubectl get app -n argocd
kubectl get pods -n gitlab
kubectl get pods -n dev
```

## Notes

- Bonus does not delete, scale down, or replace Part 3 workloads.
- If GitLab startup is slow, keep checking `kubectl get pods -n gitlab`.
- For the defense, demonstrate that changing image tag in GitLab repo updates app in `dev` namespace.
