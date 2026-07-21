# metrics-server

Upstream chart: [`kubernetes-sigs/metrics-server`](https://github.com/kubernetes-sigs/metrics-server) via `https://kubernetes-sigs.github.io/metrics-server/`.

| | |
|---|---|
| Chart version (pinned) | `3.13.1` |
| App version | `0.8.1` |
| Namespace | `metrics-server` |

Provides the `metrics.k8s.io` aggregated API used by `kubectl top`,
HorizontalPodAutoscaler, and VerticalPodAutoscaler recommenders. See
`docs/architecture/autoscaling.md`.

## Kind-specific note

Kind's kubelet certificates are not signed by a CA metrics-server trusts by
default, so `values-dev.yaml` sets `args: [--kubelet-insecure-tls]`. This
flag is Kind-only — **qa/values-qa.yaml and prod/values-prod.yaml do NOT
set it**; real clusters must have properly signed kubelet serving certs
(kubeadm/managed-Kubernetes clusters typically do out of the box).

## Consumption paths

Same dual-path pattern as `infrastructure/ingress-nginx/`.
