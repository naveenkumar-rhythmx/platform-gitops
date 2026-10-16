#!/usr/bin/env bash
#
# teardown.sh — delete ALL enterprise Kind clusters + kubeconfig entries
#
# Usage:
#   ./bootstrap/scripts/teardown.sh [--yes|-y]
#
set -euo pipefail

CLUSTERS=(
  rhythmx-platform
  rhythmx-development
  rhythmx-qa
  rhythmx-production
  rhythmx-gitops
)
ASSUME_YES="${1:-}"

log() { printf '\n\033[1;36m[teardown]\033[0m %s\n' "$*"; }
die() { printf '\n\033[1;31m[teardown] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command -v kind >/dev/null 2>&1 || die "kind is not installed."
docker info >/dev/null 2>&1 || die "Docker/OrbStack is not running. Start OrbStack first."

if [[ "${ASSUME_YES}" != "--yes" && "${ASSUME_YES}" != "-y" ]]; then
  read -r -p "Delete ALL rhythmx Kind clusters and kubeconfig entries? [y/N] " confirm
  case "${confirm}" in
    y|Y|yes|YES) : ;;
    *) log "Aborted."; exit 1 ;;
  esac
fi

for name in "${CLUSTERS[@]}"; do
  if kind get clusters 2>/dev/null | grep -qx "${name}"; then
    log "Deleting Kind cluster '${name}' ..."
    kind delete cluster --name "${name}"
  fi
  ctx="kind-${name}"
  kubectl config delete-context "${ctx}" >/dev/null 2>&1 || true
  kubectl config delete-cluster "${ctx}" >/dev/null 2>&1 || true
  kubectl config unset "users.${ctx}" >/dev/null 2>&1 || true
done

log "All rhythmx Kind clusters removed."
log "Recreate with: ./bootstrap/scripts/00-create-enterprise-clusters.sh"
