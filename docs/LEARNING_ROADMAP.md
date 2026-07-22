# Learning Roadmap — Enterprise GitOps on Kind

This guide walks **Day 0 → production-shaped GitOps** on your MacBook.
Each phase is executable. Do not skip explanations.

## Mental model (Fortune 500)

```
Developer laptop
    │  git push
    ▼
GitHub (source of truth for CODE)
    │  GitHub Actions CI
    ▼
GHCR (signed OCI images) + OCI Helm charts
    │  bot PR / human promotion PR
    ▼
GitHub (source of truth for DESIRED STATE)
    │  platform-gitops + application-config
    ▼
Argo CD (pull-based reconciler)
    │  continuously compares live vs Git
    ▼
Kubernetes (Kind locally / EKS|AKS|GKE in prod)
```

**Critical enterprise rule:** CI never runs `kubectl apply` to production.
CI updates Git. Argo CD applies. That is GitOps.

## Repository ownership

| Repo | Owns | Does NOT own | Team |
|------|------|--------------|------|
| `application-source` (user/order/inventory) | Code, unit tests, Dockerfile, app CI | Cluster YAML, prod replicas | App teams |
| `platform-helm-charts` | How a service is packaged (Deployment, HPA, probes) | Which image tag is in prod | Platform + Apps |
| `application-config` | Env overlays: image digest, replicas, ingress host | Chart templates | Release Eng + Apps |
| `platform-gitops` | Argo CD, projects, ApplicationSets, ingress, policies | Business logic | Platform Eng |

## Environments on one Kind cluster

Production orgs often have **three clusters**. Locally we simulate with:

| Logical env | Kubernetes reality on Kind | Namespace pattern |
|-------------|----------------------------|-------------------|
| Development | labels + namespaces | `apps-*-dev`, `infra-*-dev` |
| QA | same cluster, different NS | `apps-*-qa` |
| Production | same cluster, stricter sync windows / manual sync | `apps-*-prod` |

**Why this is valid learning:** AppProjects, ApplicationSets, promotion PRs,
and sync policies behave the same. Only the `destination.server` would change
for real multi-cluster (registered via Argo CD cluster secrets).

## Phases

1. **Kind cluster** — topology that looks like a small HA-capable cluster
2. **Helm mental model + Argo CD install** — the one chicken/egg Helm release
3. **Projects + repo credentials + App-of-Apps** — blast-radius isolation
4. **One microservice end-to-end** — Helm → Application → pods
5. **GitOps demos** — scale, image bump, drift self-heal
6. **Platform addons** — ingress, metrics-server, ESO, observability folders

## Commands cheat-sheet

```bash
cd ~/Projects/enterprise-gitops-platform/platform-gitops
./bootstrap/scripts/01-create-kind-cluster.sh
./bootstrap/scripts/02-install-argocd.sh
# then Phase 3 scripts / make bootstrap
```
