# cert-manager

Upstream chart: [`jetstack/cert-manager`](https://github.com/cert-manager/cert-manager) via `https://charts.jetstack.io`.

| | |
|---|---|
| Chart / app version (pinned) | `1.21.0` (chart version tracks app version for this chart) |
| Namespace | `cert-manager` |
| CRDs | Installed by the chart (`installCRDs: true` / `crds.enabled: true`) |

## Consumption paths

Same dual-path pattern as `infrastructure/ingress-nginx/` — see that
directory's README for the full explanation. In short:
`clusters/<env>/infrastructure/kustomization.yaml` uses
`values-<env>.yaml` directly (self-contained); `applications/infrastructure/cert-manager.yaml`
layers `values.yaml` + `values-<env>.yaml` via Argo CD multi-source.

## ClusterIssuers

See `cluster-issuers.yaml` in this directory: a `selfsigned-issuer` (used
by default, zero external dependencies, ideal for Kind/dev) and a
`letsencrypt-staging` `ClusterIssuer` template (HTTP-01 challenge via the
`nginx` IngressClass) for environments with real DNS + a publicly
reachable ingress. **`letsencrypt-prod` is intentionally NOT enabled by
default** — flip the staging server URL to the production ACME endpoint
only after staging validation succeeds end-to-end (rate limits on the
production endpoint are much stricter).

## Notable values knobs

- `installCRDs` / `crds.enabled: true` — required; without it,
  `Certificate`/`ClusterIssuer` CRs fail to apply.
- `webhook.timeoutSeconds` — bumped slightly above chart default in
  `values.yaml` to reduce false-negative admission timeouts on slow/loaded
  clusters.
- `prometheus.enabled` — wire into `infrastructure/monitoring` once live.
