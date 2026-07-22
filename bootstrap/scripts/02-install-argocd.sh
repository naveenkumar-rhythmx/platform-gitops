#!/usr/bin/env bash
#
# 02-install-argocd.sh — Phase 2
#
# Installs CENTRALIZED Argo CD (Helm only) onto the management cluster
# kind-rhythmx-platform. Workload clusters do NOT get Argo CD.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PLATFORM_CONTEXT="${PLATFORM_CONTEXT:-kind-rhythmx-platform}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_RELEASE_NAME="${ARGOCD_RELEASE_NAME:-argo-cd}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-10.1.4}"
VALUES_FILE="${VALUES_FILE:-${REPO_ROOT}/argocd/install/values.yaml}"
ARGO_HELM_REPO_URL="https://argoproj.github.io/argo-helm"

log() { printf '\n\033[1;36m[02-install-argocd]\033[0m %s\n' "$*"; }
die() { printf '\n\033[1;31m[02-install-argocd] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command -v helm >/dev/null    || die "helm is not installed"
command -v kubectl >/dev/null || die "kubectl is not installed"
[[ -f "${VALUES_FILE}" ]]     || die "Values file not found: ${VALUES_FILE}"

kubectl config get-contexts "${PLATFORM_CONTEXT}" >/dev/null 2>&1 \
  || die "Context ${PLATFORM_CONTEXT} not found. Run 00-create-enterprise-clusters.sh first."

log "Using management cluster context: ${PLATFORM_CONTEXT}"
kubectl config use-context "${PLATFORM_CONTEXT}"

log "Adding/updating argo Helm repo"
helm repo add argo "${ARGO_HELM_REPO_URL}" >/dev/null 2>&1 || true
helm repo update argo

log "Ensuring namespace ${ARGOCD_NAMESPACE}"
kubectl create namespace "${ARGOCD_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace "${ARGOCD_NAMESPACE}" \
  platform.rhythmx.io/environment=platform \
  platform.rhythmx.io/plane=control \
  --overwrite

log "Helm upgrade --install Argo CD chart=${ARGOCD_CHART_VERSION}"
helm upgrade --install "${ARGOCD_RELEASE_NAME}" argo/argo-cd \
  --version "${ARGOCD_CHART_VERSION}" \
  --namespace "${ARGOCD_NAMESPACE}" \
  --create-namespace \
  --values "${VALUES_FILE}" \
  --wait --timeout 8m0s

log "Waiting for core components"
kubectl -n "${ARGOCD_NAMESPACE}" rollout status deploy/"${ARGOCD_RELEASE_NAME}"-argocd-server --timeout=180s
kubectl -n "${ARGOCD_NAMESPACE}" rollout status sts/"${ARGOCD_RELEASE_NAME}"-argocd-application-controller --timeout=180s

log "Argo CD hub installed on ${PLATFORM_CONTEXT}"
echo "  UI:  kubectl --context ${PLATFORM_CONTEXT} -n ${ARGOCD_NAMESPACE} port-forward svc/${ARGOCD_RELEASE_NAME}-argocd-server 8080:443"
echo "  user: admin"
echo "  pass: kubectl --context ${PLATFORM_CONTEXT} -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo
log "Next: ./bootstrap/scripts/05-register-clusters.sh"
