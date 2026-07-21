# Operations Guide

## Daily operations

### Checking overall platform health

```bash
kubectl -n argocd get applications -o wide
# or, with the argocd CLI:
argocd app list
argocd app get dev-infrastructure
```

Look for `SYNC STATUS` = `Synced` and `HEALTH STATUS` = `Healthy` on every
Application. `OutOfSync` is expected transiently right after a Git push;
persistent `OutOfSync` + `Degraded` needs investigation (see
`docs/runbooks/failed-sync.md`).

### Manually triggering a sync

Automated sync (`syncPolicy.automated`) is enabled on virtually every
Application in this repo, so manual syncs are rarely needed — but for a
prod Application inside a closed sync window, or to force a resync after
fixing drift:

```bash
argocd app sync prod-user-service
# or, staying purely kubectl-native:
kubectl -n argocd patch application prod-user-service \
  --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}'
```

If the AppProject's `syncWindows` is currently in a `deny` state for that
Application, this requires the `platform-admin`/`release-engineering` Argo
CD RBAC role (see `argocd/rbac/rbac-cm.yaml`) and should follow
`docs/runbooks/break-glass.md`.

### Adding a new infrastructure addon

1. Create `infrastructure/<addon>/` following the
   `infrastructure/ingress-nginx/` pattern (values.yaml + values-<env>.yaml
   + README.md).
2. Add a `helmCharts` entry to each
   `clusters/<env>/infrastructure/kustomization.yaml`.
3. Pin the version in `VERSIONS.md`.
4. Add a corresponding entry to `projects/proj-infrastructure.yaml`'s
   `destinations`/`clusterResourceWhitelist` if it needs a new namespace or
   cluster-scoped resource kind.
5. Open a PR — CI (`validate.yaml`) runs `kustomize build --enable-helm`
   against every `clusters/<env>/infrastructure` to catch syntax errors.

### Adding a new platform addon (policy/observability)

Same pattern as above but targeting
`clusters/<env>/platform/kustomization.yaml` and
`projects/proj-platform.yaml`.

### Adding a new application (workload)

Nothing to do in THIS repo — add the service to `application-config`
under `apps/<service>/{base,overlays/{dev,qa,prod}}`, matching the existing
services' layout. `app-of-apps/applicationset-workloads.yaml`'s git
directory generator picks it up automatically on the next reconciliation
(default poll: 3 minutes). Do also add the namespace + quota + network
policy entries to `clusters/<env>/apps/{namespaces,quotas,network-policies}.yaml`
for each environment (Platform Engineering approval required — see
`CODEOWNERS`).

### Rotating repository credentials

```bash
export GIT_USERNAME="svc-argocd-sync"
export GIT_TOKEN="<new token>"
./bootstrap/scripts/04-register-repos.sh
```

Idempotent — safe to re-run any time a token is rotated.

### Upgrading Argo CD itself

1. Bump the version in `bootstrap/scripts/02-install-argocd.sh` (default
   `ARGOCD_CHART_VERSION`) and `VERSIONS.md`.
2. Review the [argo-helm chart changelog](https://github.com/argoproj/argo-helm/releases)
   for values schema changes; adjust `argocd/install/values.yaml` /
   `values-prod.yaml` accordingly.
3. Re-run `./bootstrap/scripts/02-install-argocd.sh` (idempotent
   `helm upgrade --install`).
4. Verify `kubectl -n argocd get pods` all report `Running`/`Ready` and
   `argocd version` matches the new pin.

### Reviewing policy violations

```bash
kubectl get clusterpolicyreport -A
kubectl get policyreport -A -o wide
```

Or via the Kyverno dashboard/CLI (`kubectl kyverno` plugin) if installed
locally. See `policies/README.md` for the compliance mapping and
`Audit`-vs-`Enforce` posture per policy.

## Weekly / periodic operations

- Review `VERSIONS.md` against upstream chart release notes for security
  patches (cert-manager, ingress-nginx, external-secrets in particular
  ship security fixes fairly often).
- Review Argo CD notification history in `#rhythmx-platform-alerts` for
  recurring sync failures that indicate a systemic (not one-off) issue.
- Audit `argocd/rbac/rbac-cm.yaml` group bindings against current team
  rosters (offboarded engineers, team moves).
