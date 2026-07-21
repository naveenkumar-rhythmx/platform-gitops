# Deployment Strategies

This platform supports multiple deployment strategies at the workload
level; the strategy is chosen per-service in `application-config`
(base/overlay manifests), not dictated globally by `platform-gitops`. This
document is the platform-level reference for what's available and when to
use each.

## Rolling update (default)

Standard Kubernetes `Deployment` `RollingUpdate` strategy. Default for
every service unless a service explicitly opts into Argo Rollouts (below).

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%
      maxSurge: 25%
```

**Use when:** the service is stateless, has a health check that reliably
reflects readiness, and a brief mixed-version window during rollout is
acceptable (true for the vast majority of services).

## Blue-green (via Argo Rollouts)

Two full replica sets (`active`/`preview`) behind a Service; traffic cuts
over atomically after the preview set passes health checks (and optionally
a manual promotion gate).

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    blueGreen:
      activeService: my-service-active
      previewService: my-service-preview
      autoPromotionEnabled: false # require manual `kubectl argo rollouts promote`
      scaleDownDelaySeconds: 300
```

**Use when:** a service cannot tolerate ANY mixed-version traffic (e.g.
strict API contract changes, schema-coupled releases) and instant rollback
(swap active/preview back) matters more than the 2x resource cost during
rollout.

## Canary (via Argo Rollouts)

Gradual traffic shift to the new version with automated analysis (metrics
from Prometheus) gating each step.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    canary:
      steps:
        - setWeight: 10
        - pause: { duration: 5m }
        - analysis:
            templates:
              - templateName: success-rate
        - setWeight: 50
        - pause: { duration: 10m }
        - setWeight: 100
      trafficRouting:
        nginx:
          stableIngress: my-service
```

**Use when:** the service has enough traffic volume for statistically
meaningful canary analysis and a service mesh/ingress controller capable of
weighted traffic splitting (ingress-nginx's `canary` annotations, or a
mesh if one is introduced later).

## Progressive delivery prerequisites (platform-level)

Argo Rollouts is NOT currently installed by this repo (not in
`infrastructure/` or `applications/platform/`) — it is a deliberate
**day-2 addition**, added once at least one service needs blue-green/canary
beyond plain rolling updates. When adding it:

1. Add `infrastructure/argo-rollouts/` following the same wrapper pattern
   as `infrastructure/ingress-nginx/` (values.yaml + per-env overlays + README).
2. Add it to `app-of-apps/applicationset-platform.yaml`'s scope (or a new
   dedicated Application) at sync-wave `2`.
3. Add `argoproj.io` `Rollout`/`AnalysisTemplate` to
   `projects/proj-applications.yaml`'s `namespaceResourceWhitelist` (already
   present — see that file — so no AppProject change needed).
4. Install the `kubectl argo rollouts` plugin for operators; the Argo CD UI
   also natively visualizes `Rollout` resources once the CRD is installed.

## Database migrations

Regardless of workload deployment strategy, schema migrations are treated
as a separate, ordered step — never bundled implicitly into a rolling
update. Services run migrations via a Kubernetes `Job` with an
`argocd.argoproj.io/hook: PreSync` annotation (Argo CD sync hook), so the
migration completes and succeeds BEFORE the Deployment's new
ReplicaSet is created. See `application-config/apps/<service>/base/` for
the per-service `Job` manifest (owned by app teams, not this repo).
