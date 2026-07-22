# Phase 2 — Centralized Argo CD hub

## What was installed

| Item | Value |
|------|--------|
| Cluster | `kind-rhythmx-platform` |
| Method | Helm only (`argo/argo-cd` **10.1.4** / app **v3.4.5**) |
| Release | `argo-cd` / namespace `argocd` |
| Pattern | **Centralized hub** — one Argo CD, three registered workload clusters |

## Registered clusters

| Secret | Environment label | API (Kind Docker network) |
|--------|-------------------|---------------------------|
| `cluster-development` | development | `https://<dev-cp-ip>:6443` |
| `cluster-qa` | qa | `https://<qa-cp-ip>:6443` |
| `cluster-production` | production | `https://<prod-cp-ip>:6443` |

Each workload has SA `kube-system/argocd-manager` (cluster-admin) — same idea as
registering AKS with a limited identity later (prefer least-privilege in prod).

## Scripts

```bash
./bootstrap/scripts/02-install-argocd.sh      # hub install
./bootstrap/scripts/05-register-clusters.sh   # register spokes
```

## UI access

```bash
kubectl config use-context kind-rhythmx-platform
kubectl -n argocd port-forward svc/argo-cd-argocd-server 8080:443
# https://localhost:8080  — user admin
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

Clusters page should list: **in-cluster**, **development**, **qa**, **production**.

## Why Fortune 500 use a hub

- One glass pane for Projects / ApplicationSets / sync windows  
- ApplicationSet **cluster generator** fans out by label (`environment=qa`)  
- AKS migration = replace Kind cluster Secrets with AKS endpoints  

## Trade-offs (honest)

| Benefit | Cost |
|---------|------|
| One upgrade, one UI | Hub must reach every cluster API (VNet peering / private link on Azure) |
| Simple AppSets | Hub credentials are powerful — lock down with AppProjects + RBAC |

## Next — Phase 3

AppProjects (Platform / Infrastructure / Applications / …), App-of-Apps,
ApplicationSets (git + cluster + matrix generators). Await **go Phase 3**.
