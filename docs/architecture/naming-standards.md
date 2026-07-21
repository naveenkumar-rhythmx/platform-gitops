# Naming Standards

## Kubernetes labels (mandatory on every owned resource)

```yaml
app.kubernetes.io/name: <component name, e.g. ingress-nginx, user-service>
app.kubernetes.io/instance: <unique instance, e.g. dev-ingress-nginx>
app.kubernetes.io/version: <chart or app version string>
app.kubernetes.io/component: <role, e.g. ingress-controller, workload, policy>
app.kubernetes.io/part-of: rhythmx-platform
app.kubernetes.io/managed-by: argocd
platform.rhythmx.io/environment: <dev|qa|prod|platform>
platform.rhythmx.io/owner: <platform-engineering|security-architecture|sre|app-teams>
```

Enforced at admission time by
`policies/kyverno/policies/require-labels.yaml` for
Deployment/StatefulSet/DaemonSet/CronJob/Service.

## Namespaces

| Pattern | Example | Used for |
|---|---|---|
| `<addon-name>` | `ingress-nginx`, `cert-manager`, `kyverno` | Infra/platform addons (one instance per cluster, no env suffix — each env IS a separate cluster) |
| `apps-<service>-<env>` | `apps-user-service-dev`, `apps-order-service-prod` | Application workload namespaces |

Namespace names are always lowercase, hyphen-separated, and match the
`service` name used in `application-config/apps/<service>/`.

## Argo CD objects

| Object | Pattern | Example |
|---|---|---|
| Application (ApplicationSet-generated, infra/platform) | `<env>-infrastructure`, `<env>-platform` | `dev-infrastructure` |
| Application (ApplicationSet-generated, workloads) | `<env>-<service>` | `dev-user-service` |
| Application (hand-written reference) | same pattern as generated, so it's an unambiguous drop-in | `dev-ingress-nginx` |
| AppProject | `proj-<domain>` | `proj-infrastructure`, `proj-applications` |
| ApplicationSet | `<domain>` (singular, since it's not per-env) | `infrastructure`, `workloads` |

## Helm releases

Release name matches the chart's canonical name (`ingress-nginx`,
`cert-manager`, `external-secrets`, `metrics-server`, `kyverno`) — no
environment suffix, since Helm release names are already scoped by
namespace, and namespaces are not env-suffixed for infra/platform addons
(see table above).

## Cluster / environment identifiers

- `platform.rhythmx.io/environment` is always one of: `dev`, `qa`, `prod`,
  or `platform` (for Argo CD's own control-plane resources, which aren't
  "in" any single target environment).
- Placeholder cluster API server hostnames follow
  `<env>-cluster-api.platform.local:6443` in dev-authored examples,
  `<env>-cluster-api.platform.example.com` for anything meant to model a
  real public-DNS-backed cluster (see `clusters/qa/infrastructure/env.yaml`,
  `clusters/prod/infrastructure/env.yaml`).

## Domain

- Local/Kind sandbox: `platform.local` (not publicly resolvable, add to
  `/etc/hosts` or rely on `curl --resolve` for local testing).
- Real environments: `<subdomain>.platform.example.com` — replace
  `example.com` with the actual registered domain before going to
  production (search the repo for `platform.example.com` when doing this
  swap — see `VERSIONS.md` and `argocd/install/values-prod.yaml` for the
  main occurrences).

## Priority classes

See `infrastructure/priority-classes/priority-classes.yaml` for the full
definitions: `platform-critical` > `platform-high` > `app-high` >
`app-low` (cluster default).

## Files and directories

- All Kustomization-managed directories are named after what they contain,
  not what consumes them (`infrastructure/ingress-nginx/`, not
  `infrastructure/dev-ingress/`).
- Per-environment overrides always live under `clusters/<env>/`, never as
  a suffix on a shared filename outside that directory (i.e. no
  `values-dev.yaml` sitting loose in a directory that also serves qa/prod
  without an unambiguous per-env directory boundary) — with the one
  documented exception of `infrastructure/<addon>/values-<env>.yaml`, which
  exists specifically to feed the reference multi-source Application
  pattern (see any `infrastructure/<addon>/README.md`).
