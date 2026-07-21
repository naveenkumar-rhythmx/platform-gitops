# Version Pins

Authoritative ledger of every third-party Helm chart/application version
this platform runs. Bump here IN THE SAME PR as the corresponding
`infrastructure/<addon>/values*.yaml`, `clusters/<env>/*/kustomization.yaml`
`helmCharts[].version`, and `bootstrap/scripts/02-install-argocd.sh`
default (for Argo CD itself) changes — a pin that's out of sync with the
actual manifests is worse than no ledger at all.

| Component | Chart version | App / image version | Chart repo | Pinned in |
|---|---|---|---|---|
| Argo CD | `10.1.4` | `v3.4.5` | `https://argoproj.github.io/argo-helm` | `bootstrap/scripts/02-install-argocd.sh`, `argocd/install/values.yaml` |
| ingress-nginx | `4.15.1` | `1.15.1` | `https://kubernetes.github.io/ingress-nginx` | `infrastructure/ingress-nginx/`, `clusters/*/infrastructure/kustomization.yaml` |
| cert-manager | `1.21.0` | `1.21.0` | `https://charts.jetstack.io` | `infrastructure/cert-manager/`, `clusters/*/infrastructure/kustomization.yaml` |
| external-secrets | `2.8.0` | `2.8.0` | `https://charts.external-secrets.io` | `infrastructure/external-secrets/`, `clusters/*/infrastructure/kustomization.yaml` |
| kyverno | `3.8.2` | `v1.18.2` | `https://kyverno.github.io/kyverno/` | `clusters/*/platform/kustomization.yaml` |
| metrics-server | `3.13.1` | `0.8.1` | `https://kubernetes-sigs.github.io/metrics-server/` | `infrastructure/metrics-server/`, `clusters/*/infrastructure/kustomization.yaml` |

## Not yet pinned (staged, see `infrastructure/monitoring/README.md`)

| Component | Status | Notes |
|---|---|---|
| kube-prometheus-stack | Floating range `>=65.0.0 <66.0.0` in `applications/platform/monitoring.yaml` | Intentionally NOT a committed pin yet — see rollout plan |
| Loki | Values staged (`infrastructure/logging/loki/values.yaml`), no chart version pinned | Same rollout gate as above |
| Tempo | Values staged (`infrastructure/tracing/tempo/values.yaml`), no chart version pinned | Same rollout gate as above |
| OpenTelemetry Collector | Values staged (`infrastructure/tracing/opentelemetry/values.yaml`), no chart version pinned | Same rollout gate as above |
| Argo Rollouts | Not installed | Day-2 addition — see `docs/architecture/deployment-strategies.md` |
| KEDA | Not installed | Day-2 addition — see `docs/architecture/autoscaling.md` |
| Velero | Not installed | Day-2 addition — see `docs/architecture/disaster-recovery.md` |

## Kubernetes version

- Kind node image: `kindest/node:v1.31.0` (see `bootstrap/kind/kind-config.yaml`)
- Minimum supported target cluster version: `1.29` (qa/prod may run newer —
  re-validate `kubeconform -kubernetes-version` in
  `.github/workflows/validate.yaml` when raising this floor)

## Deliberately rejected / reserved (no version to track)

- **Sealed Secrets** — see `infrastructure/sealed-secrets/README.md`
- **Gatekeeper/OPA** — see `policies/gatekeeper/README.md`
- **Jaeger** — migration-bridge stub only, see
  `infrastructure/tracing/jaeger/values.yaml`

## Upgrade cadence

Reviewed monthly against upstream release notes for security advisories
(cert-manager, ingress-nginx, and external-secrets are the highest-traffic
CVE surface among these). See
`docs/operations/operations-guide.md` "Weekly / periodic operations".
