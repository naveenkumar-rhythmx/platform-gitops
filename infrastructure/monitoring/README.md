# Observability stack (phased rollout)

This directory documents and stages values for the platform's observability
stack. Status: **planned, not yet enabled** on any environment — see
`applications/platform/monitoring.yaml` (manual-sync placeholder
Application) and `docs/architecture/overview.md` for the rollout plan and
rationale for staging it separately from the wave-1/wave-2 infra/policy
rollout.

## Components

| Component | Directory | Role |
|---|---|---|
| Prometheus | `prometheus/` | Metrics collection + storage (via kube-prometheus-stack) |
| Grafana | `grafana/` | Dashboards |
| Alertmanager | `alertmanager/` | Alert routing/dedup/silencing |
| Loki | `../logging/loki/` | Log aggregation |
| Tempo | `../tracing/tempo/` | Trace storage (Grafana-native) |
| Jaeger | `../tracing/jaeger/` | Trace storage/UI (alternative to Tempo — pick ONE, see below) |
| OpenTelemetry Collector | `../tracing/opentelemetry/` | Vendor-neutral collection pipeline for traces/metrics/logs |
| ServiceMonitor examples | `servicemonitors/` | Copy-paste-able `ServiceMonitor`/`PrometheusRule` CRs for app teams |

## Tempo vs. Jaeger

Both are valid Grafana-ecosystem-compatible trace stores. This platform
defaults to **Tempo** (object-storage-backed, no separate DB dependency,
first-class Grafana integration) and keeps a Jaeger values stub only for
teams/services already instrumented against the Jaeger UI/API who need a
migration bridge. Do not run both in the same environment long-term.

## Rollout plan (why this isn't live yet)

1. Finalize `kube-prometheus-stack` chart version pin (currently a floating
   range in `applications/platform/monitoring.yaml` on purpose — NOT yet a
   committed version per `VERSIONS.md`).
2. Review default alert rules against actual SLOs (avoid alert fatigue from
   upstream defaults tuned for generic clusters).
3. Decide long-term metrics retention + remote-write target (self-hosted
   Prometheus's local TSDB is not the long-term store for prod).
4. Enable per environment in RollingSync order: dev -> qa -> prod, same
   pattern as `app-of-apps/applicationset-platform.yaml`.

## ServiceMonitor / PrometheusRule ownership

Once live, app teams own `ServiceMonitor`/`PrometheusRule` objects for their
own services (allowed via `proj-applications`' `namespaceResourceWhitelist`
— see `projects/proj-applications.yaml`). `servicemonitors/` in this
directory holds only platform-level examples for onboarding.
