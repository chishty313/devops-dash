#!/usr/bin/env bash
# =============================================================================
# k8s-deploy.sh  —  Apply Kubernetes manifests (called by GitHub Actions)
#
# Required environment variables (set by the CI/CD workflow):
#   IMAGE_OWNER  — lowercase GitHub username/org (e.g. "chishty")
#   IMAGE_TAG    — commit SHA from the build-push job
#
# Usage (manual):
#   IMAGE_OWNER=chishty IMAGE_TAG=abc1234 ./scripts/k8s-deploy.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

GREEN="\033[0;32m"; YELLOW="\033[1;33m"; RED="\033[0;31m"; NC="\033[0m"
info()  { echo -e "${GREEN}[K8S]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[K8S]${NC}  $*"; }
error() { echo -e "${RED}[K8S]${NC} $*" >&2; exit 1; }

# ─── Validation ──────────────────────────────────────────────────────────────
[[ -z "${IMAGE_OWNER:-}" ]] && error "IMAGE_OWNER env var is required"
[[ -z "${IMAGE_TAG:-}"   ]] && error "IMAGE_TAG env var is required"

# Ensure kubectl is available (k3s kubeconfig)
export KUBECONFIG="${HOME}/.kube/config"
kubectl cluster-info --request-timeout=10s >/dev/null || error "kubectl cannot reach cluster"

info "Deploying images: ghcr.io/${IMAGE_OWNER}/qtec-backend:${IMAGE_TAG}"

# ─── Helper: apply a manifest with optional envsubst ─────────────────────────
apply() {
  local file="${ROOT_DIR}/$1"
  [[ -f "${file}" ]] || error "Manifest not found: ${file}"
  if grep -q 'IMAGE_OWNER\|IMAGE_TAG' "${file}" 2>/dev/null; then
    # Only substitute our two variables; leave all other $ patterns untouched
    export IMAGE_OWNER IMAGE_TAG
    envsubst '${IMAGE_OWNER} ${IMAGE_TAG}' < "${file}" | kubectl apply -f -
  else
    kubectl apply -f "${file}"
  fi
}

# ─── Apply manifests in dependency order ─────────────────────────────────────
info "Applying namespace..."
apply k8s/namespace.yml

info "Applying services..."
apply k8s/services.yml

info "Applying mongodb statefulset..."
apply k8s/mongodb-statefulset.yml

info "Applying backend deployment..."
apply k8s/backend-deployment.yml

info "Applying frontend deployment..."
apply k8s/frontend-deployment.yml

info "Applying HPA..."
apply k8s/hpa.yml

info "Applying PodDisruptionBudget..."
apply k8s/pdb.yml

info "Applying ingress..."
apply k8s/ingress.yml

# ─── Wait for rollouts ────────────────────────────────────────────────────────
info "Waiting for backend rollout..."
kubectl rollout status deployment/backend -n qtec --timeout=120s

info "Waiting for frontend rollout..."
kubectl rollout status deployment/frontend -n qtec --timeout=120s

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
info "===================================================================="
info " K8s deployment COMPLETE — image tag: ${IMAGE_TAG}"
info "===================================================================="
kubectl get pods -n qtec
echo ""
kubectl get ingress -n qtec
