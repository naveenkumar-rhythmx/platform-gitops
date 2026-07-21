#!/usr/bin/env bash
#
# 04-register-repos.sh
#
# Registers the platform's Git repositories with Argo CD as `argocd.argoproj.io`
# repository Secrets, so Applications/ApplicationSets sourcing from
# platform-helm-charts and application-config can be resolved.
#
# This script is intentionally interactive/documentation-oriented: it never
# hardcodes a real token. Provide credentials via environment variables
# (recommended: populate them from your secret manager / CI secrets store,
# never commit them).
#
# Usage:
#   export GIT_USERNAME="svc-argocd-sync"
#   export GIT_TOKEN="<PLACEHOLDER_GITHUB_PAT_OR_APP_TOKEN>"
#   ./bootstrap/scripts/04-register-repos.sh
#
# For production, prefer registering repos declaratively via
# argocd/install/values.yaml (configs.repositories / configs.credentialTemplates)
# or an ExternalSecret projecting credentials into `argocd` namespace Secrets
# labeled `argocd.argoproj.io/secret-type: repository`, rather than this
# imperative script. This script exists for first-bootstrap convenience only.

set -euo pipefail

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
GIT_USERNAME="${GIT_USERNAME:-}"
GIT_TOKEN="${GIT_TOKEN:-__REPLACE_ME_GIT_TOKEN__}"

log() { printf '\n\033[1;36m[04-register-repos]\033[0m %s\n' "$*"; }
die() { printf '\n\033[1;31m[04-register-repos] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command -v kubectl >/dev/null 2>&1 || die "kubectl is not installed."

if [[ "${GIT_TOKEN}" == "__REPLACE_ME_GIT_TOKEN__" ]]; then
  log "WARNING: GIT_TOKEN is not set — repositories will be registered as PUBLIC (read-only, unauthenticated)."
  log "         Set GIT_USERNAME/GIT_TOKEN env vars for private repos before re-running."
fi

# Repositories consumed by this platform:
#   1. platform-gitops        - this repo; desired state + Argo CD config (usually auto-registered as the Argo CD "self" repo)
#   2. platform-helm-charts   - versioned OCI/Helm charts for internal services
#   3. application-config    - environment overlays / promoted image tags per app
REPOS=(
  "https://github.com/naveenkumar-rhythmx/platform-gitops.git"
  "https://github.com/naveenkumar-rhythmx/platform-helm-charts.git"
  "https://github.com/naveenkumar-rhythmx/application-config.git"
)

register_repo() {
  local repo_url="$1"
  local secret_name
  secret_name="repo-$(echo -n "${repo_url}" | sed -E 's#https?://##; s#[^a-zA-Z0-9]+#-#g' | tr '[:upper:]' '[:lower:]' | cut -c1-50)"

  log "Registering ${repo_url} as Secret/${secret_name}"

  if [[ -n "${GIT_USERNAME}" && "${GIT_TOKEN}" != "__REPLACE_ME_GIT_TOKEN__" ]]; then
    kubectl -n "${ARGOCD_NAMESPACE}" create secret generic "${secret_name}" \
      --from-literal=type=git \
      --from-literal=url="${repo_url}" \
      --from-literal=username="${GIT_USERNAME}" \
      --from-literal=password="${GIT_TOKEN}" \
      --dry-run=client -o yaml | kubectl apply -f -
  else
    kubectl -n "${ARGOCD_NAMESPACE}" create secret generic "${secret_name}" \
      --from-literal=type=git \
      --from-literal=url="${repo_url}" \
      --dry-run=client -o yaml | kubectl apply -f -
  fi

  kubectl -n "${ARGOCD_NAMESPACE}" label secret "${secret_name}" \
    "argocd.argoproj.io/secret-type=repository" \
    "app.kubernetes.io/part-of=rhythmx-platform" \
    --overwrite
}

for repo in "${REPOS[@]}"; do
  register_repo "${repo}"
done

log "Registered repositories:"
kubectl -n "${ARGOCD_NAMESPACE}" get secrets -l argocd.argoproj.io/secret-type=repository -o custom-columns=NAME:.metadata.name,URL:.data.url

log "Done. Verify with: argocd repo list"
