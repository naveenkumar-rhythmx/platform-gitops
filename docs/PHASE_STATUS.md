# Enterprise multi-cluster lab — phase status

Runtime: **OrbStack** (Docker engine) + **Kind** (multi-cluster topology)  
Native OrbStack K8s context (`orbstack`) is available as a scratch sandbox only.

## Phase 1 — COMPLETE: Four independent clusters

| Cluster | Context | Role | Nodes |
|---------|---------|------|-------|
| `rhythmx-platform` | `kind-rhythmx-platform` | Management | 1 CP (ports 80/443/8080) |
| `rhythmx-development` | `kind-rhythmx-development` | Workload | 1 CP |
| `rhythmx-qa` | `kind-rhythmx-qa` | Workload | 1 CP |
| `rhythmx-production` | `kind-rhythmx-production` | Workload | 1 CP + 1 worker |

Platform namespaces created: `argocd`, `platform`, `monitoring`, `logging`,
`security`, `networking`, `cert-manager`, `external-secrets`, `observability`,
`shared-services`.

Docs: `docs/architecture/multi-cluster-topology.md`  
Bootstrap: `./bootstrap/scripts/00-create-enterprise-clusters.sh`

Legacy `rhythmx-gitops` single-cluster lab was deleted to free resources.

## Phase 2 — COMPLETE: Centralized Argo CD hub

- Helm install on `kind-rhythmx-platform` (chart 10.1.4 / app v3.4.5)
- Workload clusters registered: `development`, `qa`, `production`
- Scripts: `02-install-argocd.sh`, `05-register-clusters.sh`
- Details: `docs/architecture/phase2-centralized-argocd.md`

## Phase 3 — COMPLETE: AppProjects + App-of-Apps + ApplicationSets

- **8 AppProjects** (platform, infrastructure, applications, monitoring, networking, security, shared-services, data-platform)
- **5 ApplicationSets** (cluster-bootstrap, platform-bootstrap, infrastructure, platform-addons, workloads)
- **34 Applications** on the hub UI
- Bootstrap markers **Synced/Healthy** on platform + development + qa + production
- **27 workload Applications** generated (9 services × 3 envs) — manual sync until Phase 5
- Doc: `docs/architecture/phase3-app-of-apps.md`

## Next — Phase 4 (await your go)

Install platform components on the hub (ingress-nginx, cert-manager, metrics-server, ESO, Kyverno, observability stubs).

## Later phases

3. AppProjects + App-of-Apps + ApplicationSets (cluster + matrix generators)  
4. Platform components on platform cluster only  
5. Business microservices on workload clusters (~30–40 Apps)  
6. Observability, security, DR, promotion demos
