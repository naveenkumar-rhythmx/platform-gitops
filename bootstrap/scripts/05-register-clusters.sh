#!/usr/bin/env bash
#
# 05-register-clusters.sh — Phase 2
#
# Registers Kind workload clusters into the CENTRALIZED Argo CD hub on
# rhythmx-platform. Uses ServiceAccount bearer tokens + control-plane IPs on
# the shared Docker `kind` network (reachable from Argo CD pods).
#
# Azure AKS later: same Secret shape; replace server/CA/token with AKS creds
# or Workload Identity.
#
set -euo pipefail

PLATFORM_CONTEXT="${PLATFORM_CONTEXT:-kind-rhythmx-platform}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
MANAGER_NS="${MANAGER_NS:-kube-system}"
MANAGER_SA="${MANAGER_SA:-argocd-manager}"

# name|kubectl-context|environment-label
WORKLOADS=(
  "development|kind-rhythmx-development|development"
  "qa|kind-rhythmx-qa|qa"
  "production|kind-rhythmx-production|production"
)

log() { printf '\n\033[1;36m[05-register-clusters]\033[0m %s\n' "$*"; }
die() { printf '\n\033[1;31m[05-register-clusters] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command -v kubectl >/dev/null || die "kubectl required"
command -v docker >/dev/null  || die "docker required"
command -v python3 >/dev/null || die "python3 required"

kubectl config get-contexts "${PLATFORM_CONTEXT}" >/dev/null 2>&1 \
  || die "Missing context ${PLATFORM_CONTEXT}"
kubectl --context "${PLATFORM_CONTEXT}" -n "${ARGOCD_NAMESPACE}" get deploy >/dev/null 2>&1 \
  || die "Argo CD not found on hub. Run 02-install-argocd.sh first."

ensure_manager_on_workload() {
  local ctx="$1"
  log "Ensuring ${MANAGER_SA} on ${ctx}"
  kubectl --context "${ctx}" -n "${MANAGER_NS}" create sa "${MANAGER_SA}" \
    --dry-run=client -o yaml | kubectl --context "${ctx}" apply -f -
  kubectl --context "${ctx}" create clusterrolebinding "${MANAGER_SA}-binding" \
    --clusterrole=cluster-admin \
    --serviceaccount="${MANAGER_NS}:${MANAGER_SA}" \
    --dry-run=client -o yaml | kubectl --context "${ctx}" apply -f -

  # Long-lived token Secret (K8s 1.24+)
  kubectl --context "${ctx}" apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${MANAGER_SA}-token
  namespace: ${MANAGER_NS}
  annotations:
    kubernetes.io/service-account.name: ${MANAGER_SA}
type: kubernetes.io/service-account-token
EOF

  # Wait for token population
  local i
  for i in $(seq 1 30); do
    if kubectl --context "${ctx}" -n "${MANAGER_NS}" get secret "${MANAGER_SA}-token" -o jsonpath='{.data.token}' 2>/dev/null | grep -q .; then
      return 0
    fi
    sleep 1
  done
  die "Token not populated for ${MANAGER_SA} on ${ctx}"
}

control_plane_ip() {
  local kind_name="$1" # e.g. rhythmx-development
  docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${kind_name}-control-plane"
}

register_one() {
  local name="$1" ctx="$2" env_label="$3"
  local kind_name="rhythmx-${name}"
  local ip server token ca_b64 secret_name

  ensure_manager_on_workload "${ctx}"

  ip="$(control_plane_ip "${kind_name}")"
  [[ -n "${ip}" ]] || die "Could not resolve Docker IP for ${kind_name}-control-plane"
  server="https://${ip}:6443"

  token="$(kubectl --context "${ctx}" -n "${MANAGER_NS}" get secret "${MANAGER_SA}-token" -o jsonpath='{.data.token}' | base64 -d)"
  ca_b64="$(kubectl --context "${ctx}" -n "${MANAGER_NS}" get secret "${MANAGER_SA}-token" -o jsonpath='{.data.ca\.crt}')"

  secret_name="cluster-${name}"
  log "Registering cluster '${name}' → ${server} as Secret/${secret_name}"

  # Build secret without printing token
  python3 - "${ARGOCD_NAMESPACE}" "${secret_name}" "${name}" "${server}" "${token}" "${ca_b64}" "${env_label}" <<'PY' \
    | kubectl --context "${PLATFORM_CONTEXT}" apply -f -
import json, os, sys, base64
ns, secret_name, name, server, token, ca_b64, env_label = sys.argv[1:8]
config = {
  "bearerToken": token,
  "tlsClientConfig": {
    "insecure": False,
    "caData": ca_b64,
  },
}
doc = {
  "apiVersion": "v1",
  "kind": "Secret",
  "metadata": {
    "name": secret_name,
    "namespace": ns,
    "labels": {
      "argocd.argoproj.io/secret-type": "cluster",
      "platform.rhythmx.io/environment": env_label,
      "platform.rhythmx.io/cluster-role": "workload",
      "platform.rhythmx.io/part-of": "rhythmx-platform",
      "environment": env_label,
    },
  },
  "type": "Opaque",
  "stringData": {
    "name": name,
    "server": server,
    "config": json.dumps(config),
  },
}
print(json.dumps(doc))
PY
}

for row in "${WORKLOADS[@]}"; do
  IFS='|' read -r name ctx env_label <<<"${row}"
  register_one "${name}" "${ctx}" "${env_label}"
done

log "Registered cluster secrets on hub:"
kubectl --context "${PLATFORM_CONTEXT}" -n "${ARGOCD_NAMESPACE}" get secrets \
  -l argocd.argoproj.io/secret-type=cluster \
  -o custom-columns=NAME:.metadata.name,ENV:.metadata.labels.environment --no-headers

log "Restarting application-controller so it reloads cluster list"
kubectl --context "${PLATFORM_CONTEXT}" -n "${ARGOCD_NAMESPACE}" rollout restart sts/argo-cd-argocd-application-controller
kubectl --context "${PLATFORM_CONTEXT}" -n "${ARGOCD_NAMESPACE}" rollout status sts/argo-cd-argocd-application-controller --timeout=180s

log "Done. Phase 2 complete — centralized hub + 3 workload clusters registered."
echo "  Verify connectivity from UI Clusters page, or:"
echo "  kubectl --context ${PLATFORM_CONTEXT} -n ${ARGOCD_NAMESPACE} get secrets -l argocd.argoproj.io/secret-type=cluster"
