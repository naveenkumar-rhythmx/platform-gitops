# Multi-cluster enterprise topology (Phase 1)

## Why four clusters (Fortune 500 pattern)

| Cluster | Role | Runs | Azure AKS mapping |
|---------|------|------|-------------------|
| `rhythmx-platform` | Management / control plane | Argo CD, ingress, cert-manager, ESO, Kyverno, observability | Hub / mgmt AKS (or Fleet hub) |
| `rhythmx-development` | Workload | Business apps only | Dev AKS |
| `rhythmx-qa` | Workload | Business apps only | QA AKS |
| `rhythmx-production` | Workload | Business apps only | Prod AKS (separate subscription often) |

**Namespaces on one cluster ≠ environments.** Enterprises isolate kube-apiserver,
etcd, admission webhooks, and network egress per environment so a bad CNI upgrade
in QA cannot take down Production.

## OrbStack + Kind

```
┌─────────────────────────────────────────────┐
│  MacBook                                    │
│  OrbStack (Docker engine + optional K8s)    │
│    ├─ Kind: rhythmx-platform                │
│    ├─ Kind: rhythmx-development             │
│    ├─ Kind: rhythmx-qa                      │
│    └─ Kind: rhythmx-production              │
│  orbstack context = optional sandbox only   │
└─────────────────────────────────────────────┘
```

- **Kind** gives multi-cluster fidelity identical to how Argo CD talks to AKS.
- **OrbStack** is the high-performance container runtime under Kind (and provides
  a native single-node K8s at context `orbstack` if you need a quick scratch pad).

## Control plane vs data plane (centralized Argo CD)

Lab default: **one Argo CD on `rhythmx-platform`** managing all workload clusters.
See [argocd-topology.md](./argocd-topology.md).

```
                    GitHub (desired state)
                           │
                           ▼
              ┌────────────────────────┐
              │  rhythmx-platform      │
              │  Argo CD (Helm hub)    │
              │  AppProjects / AppSets │
              └───────────┬────────────┘
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
   development          qa          production
   (apps only)      (apps only)     (apps only)
```

Workload clusters are registered as Argo CD cluster secrets (same mechanism as AKS).
ApplicationSets use the **cluster generator** so one Git commit targets all envs.

## Resource shape (laptop)

| Cluster | Nodes | Rationale |
|---------|-------|-----------|
| platform | 1 CP | HostPorts 80/443/8080 for ingress + UI |
| development | 1 CP | Cheap inner loop |
| qa | 1 CP | Parity with promotion path |
| production | 1 CP + 1 worker | Mild HA scheduling / PDB realism |

Upgrade path to AKS: replace Kind kubeconfigs with AKS credentials; Git manifests stay.

## Ownership

| Concern | Owner |
|---------|-------|
| Creating/destroying clusters | Platform Engineering |
| Registering clusters in Argo CD | Platform Engineering |
| Deploying apps into workload clusters | App teams via GitOps (no kubectl to prod) |
| Platform addons on management cluster | Platform + Observability + Security teams |

## Common mistakes

1. Installing Argo CD on every cluster (breaks hub model; use agents only if you adopt ApplicationSet + pull model later).
2. Putting Prometheus on every tiny Kind node before the hub works — start hub-first.
3. Using OrbStack native K8s as “production” while Kind is “dev” inconsistently — pick Kind multi-cluster as the lab standard.
