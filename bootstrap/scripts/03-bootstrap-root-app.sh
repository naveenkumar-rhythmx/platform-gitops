#!/usr/bin/env bash
# 03-bootstrap-root-app.sh — Phase 3
# Applies AppProjects + root App-of-Apps on the centralized hub.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PLATFORM_CONTEXT="${PLATFORM_CONTEXT:-kind-rhythmx-platform}"

log() { printf '\n\033[1;36m[03-bootstrap-root-app]\033[0m %s\n' "$*"; }
die() { printf '\n\033[1;31m[03-bootstrap-root-app] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

kubectl config use-context "${PLATFORM_CONTEXT}"

log "Applying AppProjects"
kubectl apply -k "${REPO_ROOT}/projects"

log "Applying root Application + ApplicationSets (local apply; Git takes over after push)"
kubectl apply -k "${REPO_ROOT}/app-of-apps"

log "Applications / ApplicationSets:"
kubectl -n argocd get appprojects
kubectl -n argocd get applicationsets
kubectl -n argocd get applications -o wide || true

log "Done. Ensure Git remotes are registered (04-register-repos.sh) and main is pushed."
