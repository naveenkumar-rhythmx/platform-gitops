# Argo CD topology decision (lab)

## Decision for this lab: **centralized (hub) Argo CD**

```
GitHub
  │
  ▼
rhythmx-platform  (Argo CD — single control plane)
  ├── registers → rhythmx-development
  ├── registers → rhythmx-qa
  └── registers → rhythmx-production
```

| Cluster | Runs Argo CD? | What Argo CD manages there |
|---------|---------------|----------------------------|
| `rhythmx-platform` | **Yes (hub)** | Itself (addons) + all workload clusters via cluster secrets |
| `rhythmx-development` | No | Apps only (destination of hub Applications) |
| `rhythmx-qa` | No | Apps only |
| `rhythmx-production` | No | Apps only |

## Why centralized is fine (and common)

- **One UI** — Platforms, Projects, Clusters, ApplicationSets in one place (what you asked the dashboard to look like)
- **One upgrade path** — patch Argo CD once
- **ApplicationSet cluster generator** — natural fit: one AppSet fans out to registered clusters
- **Fortune 500 usage** — still the dominant pattern for many platform teams until network/Zero-Trust forces spokes

## When enterprises move to per-cluster later

- Private AKS with no hub API path into prod VNets  
- Regulated isolation (prod credentials must not leave prod)  
- Hub blast-radius / audit findings  

That is a **migration**, not a day-1 requirement. Same Git repos work either way; only install location and cluster secrets change.

## AKS migration

| Lab (Kind) | Azure |
|------------|--------|
| Argo CD Helm on platform Kind | Argo CD on mgmt AKS (or Azure Arc / Fleet hub) |
| `argocd cluster add` / cluster Secret for each Kind | Same Secret shape with AKS kubeconfig / Workload Identity |
| AppProjects restrict destinations by cluster+namespace | Identical |

## Security controls we still enforce on the hub

- AppProjects: repo / namespace / cluster destination allow-lists  
- Prod sync windows + manual sync where required  
- RBAC roles per team (Platform, Payments, Identity, …)  
- No app team kubeconfig to production — Git PRs only  

Per-cluster Argo CD remains documented as an optional evolution in older notes; **this lab implements centralized**.
