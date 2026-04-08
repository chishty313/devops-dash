#!/usr/bin/env bash
# =============================================================================
# k8s-setup.sh  —  ONE-TIME server bootstrap for the optional K8s lane
#
# Run this ONCE on the VM, as the deploy user (e.g. azureuser).
# It is safe to re-run; every step is idempotent.
#
# What it does:
#   1. Installs k3s (lightweight Kubernetes) WITHOUT Traefik
#      (Traefik disabled to avoid conflict with Docker nginx on ports 80/443)
#   2. Installs nginx-ingress-controller and pins it to NodePort 30080 (HTTP)
#   3. Copies kubeconfig so the deploy user can run kubectl without sudo
#   4. Installs gettext-base (provides envsubst, needed by k8s-deploy.sh)
#   5. (Optional) configures GHCR pull credentials for private images
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

GREEN="\033[0;32m"; YELLOW="\033[1;33m"; RED="\033[0;31m"; NC="\033[0m"
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ─── 1. Prerequisites ────────────────────────────────────────────────────────
info "Installing prerequisites..."
sudo apt-get update -qq
sudo apt-get install -y curl wget gettext-base

# ─── 2. Install k3s (no Traefik — Docker nginx owns ports 80/443) ────────────
if command -v k3s &>/dev/null; then
  info "k3s already installed: $(k3s --version | head -1)"
else
  info "Installing k3s..."
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik" sh -
  info "Waiting for k3s to become ready..."
  sudo k3s kubectl wait --for=condition=Ready node --all --timeout=120s
fi

# ─── 3. Configure kubectl for the current (non-root) user ────────────────────
info "Configuring kubectl for ${USER}..."
mkdir -p "${HOME}/.kube"
sudo cp /etc/rancher/k3s/k3s.yaml "${HOME}/.kube/config"
sudo chown "${USER}:${USER}" "${HOME}/.kube/config"
chmod 600 "${HOME}/.kube/config"

# Persist KUBECONFIG in .bashrc so every future SSH session picks it up
if ! grep -q "KUBECONFIG" "${HOME}/.bashrc" 2>/dev/null; then
  echo 'export KUBECONFIG="${HOME}/.kube/config"' >> "${HOME}/.bashrc"
fi
export KUBECONFIG="${HOME}/.kube/config"

info "kubectl ready: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"

# ─── 4. Install nginx-ingress-controller (bare-metal / NodePort) ─────────────
INGRESS_VERSION="v1.10.1"
INGRESS_NS="ingress-nginx"

if kubectl get ns "${INGRESS_NS}" &>/dev/null; then
  info "nginx-ingress namespace already exists — skipping install"
else
  info "Installing nginx-ingress-controller ${INGRESS_VERSION}..."
  kubectl apply -f \
    "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${INGRESS_VERSION}/deploy/static/provider/baremetal/deploy.yaml"

  # Wait on the Deployment, not on pods by label: `kubectl wait pod` fails with
  # "no matching resources found" if pods are not created yet (race) or labels differ.
  info "Waiting for ingress-nginx-controller deployment (up to 3 minutes)..."
  kubectl rollout status deployment/ingress-nginx-controller \
    -n "${INGRESS_NS}" \
    --timeout=180s
fi

# ─── 5. Pin nginx-ingress to NodePort 30080 (HTTP) ───────────────────────────
# Docker nginx proxies qtec-k8s.chishty.me → 127.0.0.1:30080
# so we need a known, stable port.
info "Patching nginx-ingress NodePort to 30080 (HTTP)..."
kubectl patch svc ingress-nginx-controller \
  -n "${INGRESS_NS}" \
  --type=merge \
  -p='{
    "spec": {
      "ports": [
        {"name":"http",  "port":80,  "protocol":"TCP","targetPort":"http", "nodePort":30080},
        {"name":"https", "port":443, "protocol":"TCP","targetPort":"https","nodePort":30443}
      ]
    }
  }' || warn "NodePort patch failed — may already be set or cluster version differs"

info "nginx-ingress NodePort status:"
kubectl get svc ingress-nginx-controller -n "${INGRESS_NS}"

# ─── 6. (Optional) GHCR private-image pull secret ────────────────────────────
# If your GitHub packages are PRIVATE, uncomment the lines below and fill in values.
# If packages are PUBLIC, skip this section entirely.
#
# GITHUB_USER="your-github-username"
# GITHUB_PAT="ghp_xxxxxxxxxxxx"   # PAT with read:packages scope
#
# kubectl create namespace qtec --dry-run=client -o yaml | kubectl apply -f -
# kubectl create secret docker-registry ghcr-pull \
#   --namespace=qtec \
#   --docker-server=ghcr.io \
#   --docker-username="${GITHUB_USER}" \
#   --docker-password="${GITHUB_PAT}" \
#   --dry-run=client -o yaml | kubectl apply -f -
#
# Then add under spec.template.spec in backend/frontend deployments:
#   imagePullSecrets:
#     - name: ghcr-pull

# ─── 7. Create qtec namespace (idempotent) ────────────────────────────────────
info "Creating qtec namespace..."
kubectl apply -f "${ROOT_DIR}/k8s/namespace.yml"

# ─── Done ────────────────────────────────────────────────────────────────────
echo ""
info "=================================================================="
info " k3s + nginx-ingress setup COMPLETE"
info "=================================================================="
info " NEXT STEPS:"
info "  1. Get TLS cert for qtec-k8s.chishty.me (see docs/K8S_OPTIONAL_GUIDE.md)"
info "  2. Reload Docker nginx:  docker compose exec nginx nginx -s reload"
info "  3. Create Kubernetes secrets:"
info "     kubectl create secret generic qtec-secrets \\"
info "       --namespace=qtec \\"
info "       --from-literal=mongodb_uri='mongodb+srv://...'"
info "  4. Push to main — GitHub Actions will deploy k8s manifests automatically"
info "=================================================================="
