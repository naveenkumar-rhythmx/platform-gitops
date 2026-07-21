# Autoscaling

## HPA (Horizontal Pod Autoscaler) — default for stateless services

- **Requires:** `metrics-server` (installed by every environment's
  `infrastructure` Application — see `infrastructure/metrics-server/`) for
  CPU/memory metrics, or a custom/external metrics adapter (Prometheus
  Adapter) for request-rate/latency-based scaling once
  `infrastructure/monitoring` is live.
- **Owned by:** app teams, defined alongside the Deployment in
  `application-config/apps/<service>/base/` (or per-env overlay if scaling
  bounds differ by environment, which they usually should — dev often
  disables HPA entirely / pins replicas to 1).
- **Platform guardrail:** every workload's `Deployment.spec.replicas` and
  `HorizontalPodAutoscaler.spec.metrics` are in each generated
  Application's `ignoreDifferences` (see
  `app-of-apps/applicationset-workloads.yaml`) so Argo CD doesn't fight the
  HPA controller over the live replica count.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: user-service
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: user-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

## VPA (Vertical Pod Autoscaler) — recommendation-only by default

Not installed by default. When adopted, run VPA in `Off` mode
(`updateMode: "Off"`) so it only emits `.status.recommendation` (visible
via `kubectl describe vpa`) rather than actually evicting/resizing pods —
use those recommendations to right-size `requests`/`limits` in
`application-config` manually or via periodic review, avoiding the
disruption risk of `Auto`/`Recreate` update modes in a platform that
already runs HPA on most services (VPA + HPA on the SAME resource metric
is an anti-pattern — see Kubernetes docs).

**Use when:** a service's resource requests are chronically miscalibrated
(either wasting quota headroom or getting OOMKilled) and manual profiling
hasn't kept up.

## KEDA — event-driven / non-CPU-metric scaling

Not installed by default; a natural fit for:

- Queue-depth-driven workers (e.g. a notification/order processing worker
  scaling on SQS/RabbitMQ/Kafka lag rather than CPU).
- Scale-to-zero for genuinely bursty batch workloads.
- Cron-based scaling (predictable traffic patterns, e.g. business-hours
  scale-up).

When adopted, install following the `infrastructure/<addon>/` wrapper
pattern (`infrastructure/keda/values.yaml` + per-env overlays), add to
`app-of-apps/applicationset-platform.yaml`'s scope, and add `keda.sh`
`ScaledObject`/`ScaledJob` to `projects/proj-applications.yaml`'s
`namespaceResourceWhitelist`.

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: notification-worker
spec:
  scaleTargetRef:
    name: notification-worker
  minReplicaCount: 0
  maxReplicaCount: 20
  triggers:
    - type: rabbitmq
      metadata:
        queueName: notifications
        queueLength: "50"
```

## Cluster autoscaling (node level)

Out of scope for this repo (managed by the cloud provider's node
autoscaler — e.g. AKS/EKS cluster autoscaler or Karpenter — configured as
part of the qa/prod cluster's own infrastructure-as-code, not
`platform-gitops`). This repo's `infrastructure/priority-classes/` and
`infrastructure/resource-quotas/` exist to make node-level autoscaling
decisions predictable (accurate resource requests -> accurate scale-up
triggers) regardless of which node autoscaler is in front of it.
