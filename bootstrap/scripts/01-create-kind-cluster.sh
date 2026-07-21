#!/usr/bin/env bash
#
# 01-create-kind-cluster.sh
#
# Creates the local Kind cluster "rhythmx-gitops" used as the GitOps bootstrap
# sandbox for the rhythmx-platform. Idempotent: re-running when the cluster
# already exists is a no-op (with a warning) rather than a failure.
#
# Usage:
#   ./bootstrap/scripts/01-create-kind-cluster.sh
#
# Env overrides:
#   CLUSTER_NAME   (default: rhythmx-gitops)
#   KIND_CONFIG    (default: bootstrap/kind/kind-config.yaml)
#   KUBE_CONTEXT   (default: kind-${CLUSTER_NAME})

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

CLUSTER_NAME="${CLUSTER_NAME:-rhythmx-gitops}"
KIND_CONFIG="${KIND_CONFIG:-${REPO_ROOT}/bootstrap/kind/kind-config.yaml}"
KUBE_CONTEXT="${KUBE_CONTEXT:-kind-${CLUSTER_NAME}}"

log() { printf '\n\033[1;36m[01-create-kind-cluster]\033[0m %s\n' "$*"; }
die() { printf '\n\033[1;31m[01-create-kind-cluster] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command -v kind >/dev/null 2>&1    || die "kind is not installed. See https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
command -v kubectl >/dev/null 2>&1 || die "kubectl is not installed."
command -v docker >/dev/null 2>&1  || die "docker is not installed or not on PATH."

if ! docker info >/dev/null 2>&1; then
  die "Docker daemon is not reachable. Start Docker Desktop / dockerd and retry."
fi

if [[ ! -f "${KIND_CONFIG}" ]]; then
  die "Kind config not found at ${KIND_CONFIG}"
fi

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  log "Cluster '${CLUSTER_NAME}' already exists. Skipping creation (delete with bootstrap/scripts/teardown.sh to recreate)."
else
  log "Creating Kind cluster '${CLUSTER_NAME}' from ${KIND_CONFIG} ..."
  kind create cluster \
    --name "${CLUSTER_NAME}" \
    --config "${KIND_CONFIG}" \
    --wait 120s
fi

log "Setting kubectl context to ${KUBE_CONTEXT}"
kubectl config use-context "${KUBE_CONTEXT}"

log "Waiting for all nodes to report Ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=180s

log "Labeling/annotating cluster-info configmap with platform metadata (best-effort)."
kubectl -n kube-public annotate configmap cluster-info \
  platform.rhythmx.io/managed-by=platform-gitops \
  platform.rhythmx.io/cluster-name="${CLUSTER_NAME}" \
  --overwrite >/dev/null 2>&1 || true

log "Cluster nodes:"
kubectl get nodes -o wide

log "Done. Next: ./bootstrap/scripts/02-install-argocd.sh"
