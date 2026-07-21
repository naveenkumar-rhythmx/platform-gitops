#!/usr/bin/env bash
#
# 03-bootstrap-root-app.sh
#
# Applies the "app of apps" root Application plus the AppProjects it depends
# on. This is the last manual `kubectl apply` — from this point forward,
# Argo CD reconciles everything (infrastructure, platform addons, and
# workload ApplicationSets) from this Git repository.
#
# Usage:
#   ./bootstrap/scripts/03-bootstrap-root-app.sh
#
# Env overrides:
#   ARGOCD_NAMESPACE (default: argocd)
#   REPO_URL         (default: https://github.com/naveenkumar-rhythmx/platform-gitops.git)
#   TARGET_REVISION  (default: main)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
REPO_URL="${REPO_URL:-https://github.com/naveenkumar-rhythmx/platform-gitops.git}"
TARGET_REVISION="${TARGET_REVISION:-main}"

log() { printf '\n\033[1;36m[03-bootstrap-root-app]\033[0m %s\n' "$*"; }
die() { printf '\n\033[1;31m[03-bootstrap-root-app] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command -v kubectl >/dev/null 2>&1 || die "kubectl is not installed."
command -v kustomize >/dev/null 2>&1 || log "kustomize CLI not found; relying on 'kubectl apply -k' built-in kustomize support."

kubectl get ns "${ARGOCD_NAMESPACE}" >/dev/null 2>&1 || die "Namespace '${ARGOCD_NAMESPACE}' not found. Run 02-install-argocd.sh first."

log "Applying AppProjects (projects/) ..."
kubectl apply -k "${REPO_ROOT}/projects" -n "${ARGOCD_NAMESPACE}"

log "Applying root Application + top-level ApplicationSets (app-of-apps/) ..."
if [[ -n "${REPO_URL}" && "${REPO_URL}" != "https://github.com/naveenkumar-rhythmx/platform-gitops.git" ]]; then
  log "Overriding repoURL/targetRevision via envsubst is not wired by default; edit app-of-apps/root-application.yaml directly for a fork/mirror."
fi
kubectl apply -k "${REPO_ROOT}/app-of-apps" -n "${ARGOCD_NAMESPACE}"

log "Root Application status (may take a minute to go Healthy/Synced):"
kubectl -n "${ARGOCD_NAMESPACE}" get application root-app -o wide || true

log "Watch the whole tree with:"
echo "  kubectl -n ${ARGOCD_NAMESPACE} get applications -o wide"
echo "  argocd app get root-app --grpc-web   # if the argocd CLI is installed/logged in"

log "Done. GitOps reconciliation is now live from ${REPO_URL}@${TARGET_REVISION}."
