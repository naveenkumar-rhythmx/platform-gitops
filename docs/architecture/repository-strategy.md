# Repository Strategy

## The three-repo split

| Repository | Contents | Who commits | CI gate |
|---|---|---|---|
| `platform-gitops` (this repo) | Argo CD config, AppProjects, ApplicationSets/Applications, cluster desired state, policies, docs | Platform Engineering, Security Architecture (policies) | `.github/workflows/validate.yaml` — kustomize build, kubeconform |
| `platform-helm-charts` | Versioned, reusable Helm charts per service (`charts/user-service`, `charts/order-service`, ...) | Service owners | Chart lint/test, semver-gated release |
| `application-config` | Environment overlays (`apps/<service>/overlays/{dev,qa,prod}`), promoted image tags | App teams (dev overlay), Release Engineering (qa/prod bot PRs) | Schema validation, promotion workflow gates |

This mirrors the pattern recommended by the CNCF GitOps Working Group:
separate "what code does" (app source), "how it's packaged" (charts), and
"what's running where" (this repo + env overlays) so that a chart bump
never silently changes what's deployed, and a deploy never requires a
chart PR.

## Ownership boundaries (RACI)

See the root [README.md](../../README.md#ownership--raci) for the full
RACI table. In short:

- **Platform Engineering** owns everything under `argocd/`, `app-of-apps/`,
  `projects/`, `bootstrap/`, `infrastructure/` (non-policy content), and
  the overall `clusters/` skeleton.
- **Security Architecture** co-owns `policies/` (CODEOWNERS-enforced
  review) and the RBAC policy in `argocd/rbac/rbac-cm.yaml`.
- **SRE** co-owns sync windows, `infrastructure/monitoring/`, and
  `docs/runbooks/`.
- **App teams** own their `application-config` overlays and workload-level
  `ServiceMonitor`/`PrometheusRule` objects (once observability is live),
  but never this repo's `clusters/` or `projects/` content.

## Branching strategy

| Branch | Purpose | Protection |
|---|---|---|
| `main` | Production-ready desired state, continuously reconciled by every environment's Argo CD Applications | Required reviews (2), CODEOWNERS, required status checks (`validate.yaml`), no force-push |
| `feature/*`, `fix/*` | Short-lived work branches | PR into `main` only, squash-merge preferred |
| `release/*` | Coordinated platform releases (tagged `platform-vX.Y.Z` after merge) | Cut from `main` at release time, not long-lived |

Unlike `application-config` (which has meaningful long-lived
`env/{dev,qa,prod}` promotion branches because environment state actually
diverges by design), this repo intentionally does NOT use long-lived
environment branches — environment divergence here is expressed as
directory structure (`clusters/dev/` vs `clusters/qa/` vs `clusters/prod/`)
within a single `main`, so a security policy fix lands in every
environment's desired state via one PR, not three cherry-picks.

## Release strategy

- **Platform releases:** bi-weekly tagged `platform-vX.Y.Z` after a batch
  of merged PRs; the tag is informational (Argo CD tracks `main` directly,
  not tags) and exists for changelog/audit purposes.
- **Infra chart version bumps:** a PR touching the relevant
  `infrastructure/<addon>/values*.yaml` + `clusters/<env>/infrastructure/kustomization.yaml`
  `helmCharts[].version` + `VERSIONS.md`. Bump dev first, let RollingSync
  promote qa then prod (see `docs/architecture/promotion-flow.md`).
- **Argo CD's own version:** bumped in `bootstrap/scripts/02-install-argocd.sh`
  defaults + `argocd/install/values.yaml` comments + `VERSIONS.md`; re-run
  that script (idempotent `helm upgrade --install`) to apply.
- **Emergency changes:** see `docs/runbooks/break-glass.md` — time-boxed,
  requires post-hoc PR within 24h even if applied out-of-band.

## Pull request requirements

- Every PR must pass `.github/workflows/validate.yaml`.
- `CODEOWNERS` requires Security Architecture sign-off on `policies/**` and
  `argocd/rbac/**`.
- PRs that change `clusters/prod/**` should note the target sync window in
  the PR description (see `projects/proj-applications.yaml` /
  `proj-infrastructure.yaml` / `proj-platform.yaml` `syncWindows`).
