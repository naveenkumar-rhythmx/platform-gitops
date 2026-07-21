# ingress-nginx

Upstream chart: [`ingress-nginx/ingress-nginx`](https://github.com/kubernetes/ingress-nginx) via the official repo `https://kubernetes.github.io/ingress-nginx`.

| | |
|---|---|
| Chart version (pinned) | `4.15.1` |
| App version | `1.15.1` |
| Namespace | `ingress-nginx` |
| IngressClass | `nginx` (default) |

## How this directory is used

There are two consumption paths for the SAME pinned chart version, kept
consistent by convention (bump both together, see `VERSIONS.md`):

1. **Live GitOps path (preferred):** `clusters/<env>/infrastructure/kustomization.yaml`
   inflates this chart via kustomize's `helmCharts` generator
   (`kustomize.buildOptions: --enable-helm`), using a single self-contained
   `clusters/<env>/infrastructure/ingress-nginx-values.yaml`.
2. **Standalone reference path:** `applications/infrastructure/ingress-nginx.yaml`
   is a hand-written multi-source Argo CD `Application` that merges
   `values.yaml` (this file, shared defaults) + `values-<env>.yaml` (this
   directory) via Argo CD's native Helm `valueFiles` array.

`values.yaml` in this directory documents the **shared baseline** knobs;
`values-dev.yaml` / `values-qa.yaml` / `values-prod.yaml` layer environment
deltas on top of it for path #2. Path #1's per-cluster file is intentionally
self-contained (kustomize only supports one values file per chart) — see
comments in that file.

## Why ingress-nginx (vs. alternatives)

- CNCF-adjacent, extremely widely deployed, first-class Kubernetes Ingress
  support, broad annotation ecosystem (cert-manager, external-dns, etc.)
- Kind-friendly via `hostPort`/`hostNetwork` without needing MetalLB
- Team familiarity outweighs marginal performance gains from
  Envoy-based alternatives (Contour/Emissary) for this platform's traffic profile

## Notable values knobs

- `controller.ingressClassResource.default: true` — every environment has
  exactly one default IngressClass (`nginx`); do not create competing
  default IngressClasses without an explicit `ingressClassName` migration plan.
- `controller.admissionWebhooks.enabled: true` — validates Ingress objects at
  admission time; keep enabled everywhere.
- `controller.metrics.enabled` + `serviceMonitor.enabled` — wire into
  `infrastructure/monitoring/prometheus` once the observability stack is live
  in that environment (see `docs/architecture/overview.md`).
