# Phase 3 — AppProjects, App-of-Apps, ApplicationSets

## What Fortune 500 do here

| Object | Why it exists |
|--------|----------------|
| **AppProject** | Blast-radius + RBAC boundary (who can sync what where) |
| **App-of-Apps** | One root Application owns all ApplicationSets — chicken/egg ends after bootstrap |
| **ApplicationSet** | Generates N Applications from generators — no YAML explosion |

## Generators used

| Generator | Used in | Why |
|-----------|---------|-----|
| **clusters** | `cluster-bootstrap` | New registered cluster (Kind/AKS) with labels → bootstrap App appears |
| **list** | hub infra/platform, env rows in workloads | Explicit mapping when labels aren't enough |
| **git directories** | `workloads` | New `apps/<service>` folder → Apps for all envs |
| **matrix** | `workloads` | Cartesian product env × service |

**Merge generator** (not used yet): combine two generators that share a join key
(e.g. cluster name + CMDB metadata). Add when you have a second source of cluster truth.

## Projects created

`proj-platform`, `proj-infrastructure`, `proj-applications`, `proj-monitoring`,
`proj-networking`, `proj-security`, `proj-shared-services`, `proj-data-platform`

## Phase 3 success criteria

1. Eight AppProjects visible in UI  
2. ApplicationSets: cluster-bootstrap, platform-bootstrap, infrastructure, platform-addons, workloads  
3. `bootstrap-*` Applications **Synced/Healthy** on development, qa, production + platform  
4. Workload Applications **generated** (manual sync until Phase 5)

## Ownership

| Team | Project |
|------|---------|
| Platform Eng | platform, infrastructure, networking, shared-services |
| Security | security |
| Observability | monitoring |
| App / Payments / Analytics | applications, data-platform (scoped roles) |
