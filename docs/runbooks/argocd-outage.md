# Runbook: Argo CD Outage

## Symptoms

- Argo CD UI/API unreachable (`kubectl -n argocd port-forward` hangs or
  connection refused).
- `argocd-server`/`argocd-application-controller`/`argocd-repo-server` pods
  `CrashLoopBackOff`, `Pending`, or missing.
- Notifications channel goes silent (no sync-failed/health-degraded alerts
  even though you suspect drift) — Argo CD notifications controller itself
  may be down.

## Important: an Argo CD outage does NOT mean workloads are down

Argo CD is a control plane. Every resource it already reconciled continues
running via the Kubernetes control plane (kube-apiserver, kubelet,
controllers) independent of Argo CD's health. **Do not treat this as a
customer-impacting incident by default** — verify actual workload health
(`kubectl get pods -A` across app namespaces) before escalating beyond
"platform control-plane degraded."

## Triage

1. Check the namespace and pods:
   ```bash
   kubectl -n argocd get pods -o wide
   kubectl -n argocd get events --sort-by='.lastTimestamp'
   ```
2. Common root causes:
   - **Redis unhealthy** — controller/repo-server cache calls fail; check
     `kubectl -n argocd logs deploy/argo-cd-argocd-redis` (or `redis-ha`
     pods in prod).
   - **Repo-server can't clone** — expired/rotated Git credentials; check
     `kubectl -n argocd logs deploy/argo-cd-argocd-repo-server` for auth
     errors. Fix: `./bootstrap/scripts/04-register-repos.sh` with a fresh token.
   - **Resource exhaustion** — check `kubectl -n argocd top pods`; compare
     against `argocd/install/values.yaml` resource requests/limits — bump
     temporarily via `kubectl -n argocd set resources ...` if this is the
     immediate blocker, then fix properly in `values.yaml`/`values-prod.yaml`.
   - **Node/cluster-level issue** — check `kubectl get nodes`; if the whole
     cluster is unhealthy, this is a cluster incident, not an Argo CD-specific
     one.

## Recovery

### If Argo CD's own pods are unhealthy but the cluster is fine

```bash
kubectl -n argocd rollout restart deploy/argo-cd-argocd-server
kubectl -n argocd rollout restart deploy/argo-cd-argocd-repo-server
kubectl -n argocd rollout restart statefulset/argo-cd-argocd-application-controller
```

### If Argo CD's install itself is corrupted (e.g. bad Helm state)

Full reinstall is safe and non-destructive to already-running workloads
(Argo CD re-adopts resources by tracking annotation/label, not by owning
them exclusively at the etcd level):

```bash
./bootstrap/scripts/02-install-argocd.sh
./bootstrap/scripts/03-bootstrap-root-app.sh
```

### If the entire cluster is lost

See `docs/architecture/disaster-recovery.md` — full bootstrap replay from
Git (steps 1-6 in `docs/operations/getting-started.md`).

## Post-incident

- File a post-incident PR updating this runbook if the root cause wasn't
  covered above.
- If the outage caused a MISSED prod sync window
  (`projects/proj-applications.yaml` `syncWindows`), verify no prod
  Application is stuck `OutOfSync` waiting for the next window — consider
  a documented break-glass sync (`docs/runbooks/break-glass.md`) rather
  than waiting days for the next window if the pending change is benign.
