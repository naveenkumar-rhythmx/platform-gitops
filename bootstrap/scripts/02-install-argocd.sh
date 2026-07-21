#!/usr/bin/env bash
#
# 02-install-argocd.sh
#
# Installs Argo CD via the official Helm chart (argo/argo-cd) into the
# "argocd" namespace, pinned to the platform's approved version, using the
# repo-managed values file. This is the one manual `helm install` in the
# entire platform — everything after this bootstraps itself via GitOps
# (see 03-bootstrap-root-app.sh).
#
# Usage:
#   ./bootstrap/scripts/02-install-argocd.sh
#
# Env overrides:
#   ARGOCD_NAMESPACE     (default: argocd)
#   ARGOCD_RELEASE_NAME  (default: argo-cd)
#   ARGOCD_CHART_VERSION (default: 10.1.4  -- Argo CD app v3.4.5)
#   VALUES_FILE          (default: argocd/install/values.yaml)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_RELEASE_NAME="${ARGOCD_RELEASE_NAME:-argo-cd}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-10.1.4}" # Argo CD app v3.4.5
VALUES_FILE="${VALUES_FILE:-${REPO_ROOT}/argocd/install/values.yaml}"
ARGO_HELM_REPO_URL="https://argoproj.github.io/argo-helm"

log() { printf '\n\033[1;36m[02-install-argocd]\033[0m %s\n' "$*"; }
die() { printf '\n\033[1;31m[02-install-argocd] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command -v helm >/dev/null 2>&1    || die "helm is not installed."
command -v kubectl >/dev/null 2>&1 || die "kubectl is not installed."
[[ -f "${VALUES_FILE}" ]]          || die "Values file not found: ${VALUES_FILE}"

log "Adding/updating the argo Helm repo (${ARGO_HELM_REPO_URL})"
helm repo add argo "${ARGO_HELM_REPO_URL}" >/dev/null 2>&1 || true
helm repo update argo

log "Ensuring namespace '${ARGOCD_NAMESPACE}' exists"
kubectl create namespace "${ARGOCD_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace "${ARGOCD_NAMESPACE}" \
  app.kubernetes.io/part-of=rhythmx-platform \
  app.kubernetes.io/managed-by=argocd \
  platform.rhythmx.io/environment=platform \
  --overwrite

log "Installing/upgrading Argo CD chart=${ARGOCD_CHART_VERSION} release=${ARGOCD_RELEASE_NAME} ns=${ARGOCD_NAMESPACE}"
helm upgrade --install "${ARGOCD_RELEASE_NAME}" argo/argo-cd \
  --version "${ARGOCD_CHART_VERSION}" \
  --namespace "${ARGOCD_NAMESPACE}" \
  --create-namespace \
  --values "${VALUES_FILE}" \
  --wait --timeout 5m0s

log "Waiting for argocd-server rollout..."
kubectl -n "${ARGOCD_NAMESPACE}" rollout status deploy/"${ARGOCD_RELEASE_NAME}"-argocd-server --timeout=180s

log "Argo CD installed. Initial admin credentials:"
echo "  username: admin"
if kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret >/dev/null 2>&1; then
  echo -n "  password: "
  kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
  echo
  echo
  echo "  IMPORTANT: rotate/delete this secret after first login:"
  echo "    kubectl -n ${ARGOCD_NAMESPACE} delete secret argocd-initial-admin-secret"
else
  echo "  (initial-admin secret not found — SSO/dex may already be configured, or admin was already rotated)"
fi

log "Access the UI locally with:"
echo "  kubectl -n ${ARGOCD_NAMESPACE} port-forward svc/${ARGOCD_RELEASE_NAME}-argocd-server 8080:443"
echo "  open https://localhost:8080"

log "Done. Next: ./bootstrap/scripts/03-bootstrap-root-app.sh"
