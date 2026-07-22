#!/usr/bin/env bash
#
# 00-create-enterprise-clusters.sh
#
# Creates the Fortune-500-shaped Kind topology on OrbStack's container runtime:
#   rhythmx-platform     — management cluster (Argo CD + platform addons)
#   rhythmx-development  — workload
#   rhythmx-qa           — workload
#   rhythmx-production   — workload (CP + 1 worker)
#
# Why four clusters (not namespaces on one cluster):
#   - Blast radius: prod kube-apiserver failure ≠ platform control plane failure
#   - RBAC / admission / network boundaries match real AKS subscriptions
#   - Argo CD cluster secrets + ApplicationSet cluster generator work identically
#     when you later swap Kind kubeconfigs for AKS kubeconfigs
#
# OrbStack: Kind uses OrbStack's Docker engine. The native `orbstack` Kubernetes
# context remains available as an optional sandbox but is NOT part of this topology.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CLUSTERS_DIR="${REPO_ROOT}/bootstrap/kind/clusters"
DELETE_LEGACY="${DELETE_LEGACY:-true}"

log() { printf '\n\033[1;36m[00-enterprise-clusters]\033[0m %s\n' "$*"; }
die() { printf '\n\033[1;31m[00-enterprise-clusters] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command -v kind >/dev/null    || die "kind not installed"
command -v kubectl >/dev/null || die "kubectl not installed"
command -v docker >/dev/null  || die "docker not installed (OrbStack provides this)"
docker info >/dev/null 2>&1   || die "Docker/OrbStack engine not reachable"

CLUSTERS=(platform development qa production)

if [[ "${DELETE_LEGACY}" == "true" ]]; then
  if kind get clusters 2>/dev/null | grep -qx "rhythmx-gitops"; then
    log "Deleting legacy single-cluster lab 'rhythmx-gitops' to free resources..."
    kind delete cluster --name rhythmx-gitops
  fi
fi

for name in "${CLUSTERS[@]}"; do
  cfg="${CLUSTERS_DIR}/${name}.yaml"
  [[ -f "${cfg}" ]] || die "Missing Kind config: ${cfg}"
  full="rhythmx-${name}"
  if kind get clusters 2>/dev/null | grep -qx "${full}"; then
    log "Cluster '${full}' already exists — skipping create"
  else
    log "Creating Kind cluster '${full}' from ${cfg}"
    kind create cluster --name "${full}" --config "${cfg}" --wait 180s
  fi

  ctx="kind-${full}"
  kubectl config use-context "${ctx}" >/dev/null
  kubectl wait --for=condition=Ready nodes --all --timeout=180s

  # Labels used later by Argo CD ApplicationSet cluster generator
  kubectl label nodes --all \
    "platform.rhythmx.io/cluster=${full}" \
    "platform.rhythmx.io/environment=${name}" \
    --overwrite >/dev/null

  # Platform namespaces (management cluster only)
  if [[ "${name}" == "platform" ]]; then
    log "Creating platform-plane namespaces on ${full}"
    for ns in argocd platform monitoring logging security networking \
              cert-manager external-secrets observability shared-services; do
      kubectl create namespace "${ns}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
      kubectl label namespace "${ns}" \
        app.kubernetes.io/part-of=rhythmx-platform \
        platform.rhythmx.io/environment=platform \
        platform.rhythmx.io/plane=control \
        --overwrite >/dev/null
    done
  fi
done

log "Enterprise Kind topology ready:"
kind get clusters
echo
kubectl config get-contexts | grep -E 'KIND|rhythmx|NAME' || kubectl config get-contexts | grep rhythmx

log "Next (Phase 2): install Argo CD on kind-rhythmx-platform and register workload clusters."
echo "  ./bootstrap/scripts/02-install-argocd.sh   # after pointing VALUES at platform context"
echo "  ./bootstrap/scripts/05-register-clusters.sh"
