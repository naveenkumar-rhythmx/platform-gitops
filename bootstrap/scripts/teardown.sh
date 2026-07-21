#!/usr/bin/env bash
#
# teardown.sh
#
# Tears down the local Kind bootstrap sandbox entirely: deletes the Kind
# cluster (and therefore every workload, Argo CD instance, and PV backed by
# local-path-provisioner). Does NOT touch Git history/state — GitOps means
# the desired state simply gets re-applied by re-running 01→03.
#
# Usage:
#   ./bootstrap/scripts/teardown.sh [--yes]

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-rhythmx-gitops}"
ASSUME_YES="${1:-}"

log() { printf '\n\033[1;36m[teardown]\033[0m %s\n' "$*"; }
die() { printf '\n\033[1;31m[teardown] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command -v kind >/dev/null 2>&1 || die "kind is not installed."

if ! kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  log "Cluster '${CLUSTER_NAME}' does not exist. Nothing to tear down."
  exit 0
fi

if [[ "${ASSUME_YES}" != "--yes" && "${ASSUME_YES}" != "-y" ]]; then
  read -r -p "This will permanently delete Kind cluster '${CLUSTER_NAME}' and all workloads. Continue? [y/N] " confirm
  case "${confirm}" in
    y|Y|yes|YES) : ;;
    *) log "Aborted."; exit 1 ;;
  esac
fi

log "Deleting Kind cluster '${CLUSTER_NAME}' ..."
kind delete cluster --name "${CLUSTER_NAME}"

log "Removing stale kubeconfig context (best-effort) ..."
kubectl config delete-context "kind-${CLUSTER_NAME}" >/dev/null 2>&1 || true
kubectl config delete-cluster "kind-${CLUSTER_NAME}" >/dev/null 2>&1 || true
kubectl config unset "users.kind-${CLUSTER_NAME}" >/dev/null 2>&1 || true

log "Done. Recreate with: ./bootstrap/scripts/01-create-kind-cluster.sh"
