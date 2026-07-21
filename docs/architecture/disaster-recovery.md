# Disaster Recovery

## Recovery tiers

| Layer | What's lost | Recovery mechanism | RTO target |
|---|---|---|---|
| Git repositories | Nothing lost (Git is the source of truth; GitHub is the DR-safe store) | N/A — Git IS the recovery point | 0 |
| Argo CD instance | Control plane only; managed resources keep running | Re-run `bootstrap/scripts/02-install-argocd.sh` + `03-bootstrap-root-app.sh`; Argo CD re-adopts existing resources via label/annotation tracking | < 30 min |
| A single cluster (dev/qa/prod) | Everything running on that cluster | Provision a new cluster, register it, re-point `clusters/<env>/*/env.yaml` `server:` if the API endpoint changed, re-run bootstrap against it | Hours (bounded by infra provisioning time, not GitOps replay time) |
| Stateful data (databases, PVs) | Actual data | Velero (cluster-level) + application-level backups (see below) — GitOps replays DESIRED STATE, not DATA | Depends on backup RPO/RTO, tracked outside this repo |

## Git is the primary disaster recovery artifact

Because every environment's desired state (Argo CD config, infra, policy,
and — transitively, via ApplicationSets — every workload's deployed
manifest shape) is fully described in Git, **rebuilding an entire cluster
from zero is a bootstrap re-run, not a restore-from-backup exercise** for
anything that isn't stateful data:

```bash
./bootstrap/scripts/01-create-kind-cluster.sh   # or provision a real cluster via IaC
./bootstrap/scripts/02-install-argocd.sh
./bootstrap/scripts/03-bootstrap-root-app.sh
# ... wait for RollingSync to reconcile infrastructure -> platform -> workloads
```

This is exercised for real every time a developer runs the Kind sandbox
bootstrap, which is itself a continuous DR drill for the "control plane +
infra + policy" recovery path.

## What Git-based recovery does NOT cover: stateful data

- **Databases** (the `database` service in `application-config`, or any
  managed DB): backed up via the database's own mechanism (managed service
  automated backups, or a `CronJob` + object storage for self-hosted) —
  tracked in `application-config`, not this repo.
- **PersistentVolumes for platform components** (Prometheus TSDB, Loki
  chunks, Grafana dashboards-as-code excepted): Velero handles PV
  snapshot-and-restore for platform-owned stateful sets once
  `infrastructure/monitoring` is live. Velero itself is a day-2 addition
  (not yet installed) — when added, follow the
  `infrastructure/<addon>/` wrapper pattern and schedule backups via a
  `Schedule` CR, targeting the cloud provider's object storage.

## Argo CD instance recovery specifics

Argo CD's own state (Application/AppProject objects, cached repo data,
Redis) is disposable and fully reconstructible from Git EXCEPT:

- **Repository credentials** (`bootstrap/scripts/04-register-repos.sh` /
  ExternalSecret-projected repo Secrets) — must be re-provisioned from the
  secret manager, not Git (by design, see `secrets-management.md`).
- **Notification tokens** (Slack/PagerDuty) — same, re-provisioned from the
  secret manager.
- **The Argo CD admin/SSO configuration** — Dex/OIDC config is in Git
  (`argocd/install/values-prod.yaml`), but the actual OIDC client secret is
  not.

## Multi-cluster failure isolation

Because `dev`/`qa`/`prod` are independent clusters (see
`docs/architecture/overview.md` "Cluster topology model"), a full outage of
one environment's cluster does not cascade to the others — there is no
shared control plane, shared Argo CD instance, or shared network path
assumed between them (each environment's Argo CD Application destinations
point at that environment's own cluster's API server).

## Runbooks

- Argo CD itself down: `docs/runbooks/argocd-outage.md`
- A specific Application stuck: `docs/runbooks/failed-sync.md`
- Emergency out-of-band change: `docs/runbooks/break-glass.md`
