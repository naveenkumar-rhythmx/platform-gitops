# Runbook: Break-Glass Emergency Change

## When to use this

Only when ALL of the following are true:

1. There is a genuine production-impacting incident (or imminent security
   exposure) that cannot wait for the normal PR review + sync window flow.
2. The fix is understood well enough to apply confidently under pressure
   (a break-glass change made in a panic, without understanding, is how
   incidents become worse).
3. You hold the `platform-admin` or `release-engineering` Argo CD RBAC role
   (`argocd/rbac/rbac-cm.yaml`) or equivalent cluster access.

Do NOT use this runbook for routine urgency ("I want this deployed today
instead of tomorrow's window") — that's what a normal PR + manual sync
outside business-hours-gated infra windows is for; only PROD application
sync windows and prod infra/platform sync windows are genuinely restrictive.

## Procedure

### Option A: force a sync of an already-merged Git change, bypassing the sync window

```bash
argocd app sync <app-name> --force
```

This requires your Argo CD RBAC role to have `applications, sync` allowed
in the relevant AppProject even inside a `deny` window, OR the window's
`manualSync: true` flag (already set on every `syncWindows` entry in this
repo — see `projects/proj-applications.yaml`, `proj-infrastructure.yaml`,
`proj-platform.yaml`) to permit a manual override. If it's still blocked,
a `platform-admin` can temporarily patch the AppProject's window (see
Option C) — prefer Option A/B first.

### Option B: emergency kubectl patch, THEN immediately open a PR

For a true "the platform is on fire right now" scenario where even a Git
commit + Argo CD sync round-trip is too slow:

```bash
kubectl -n <namespace> patch <kind> <name> --type=<merge|json> -p '<patch>'
```

**Within 24 hours**, open a PR that makes Git match what you just did by
hand. Until that PR merges, `selfHeal: true` on the affected Application
WILL revert your manual patch on its next reconciliation — either:

- Merge the Git fix fast enough that this doesn't matter, or
- Temporarily disable that one Application's `automated` sync
  (see `docs/runbooks/failed-sync.md` "Escalation") for the duration, and
  re-enable it the moment the PR merges.

### Option C: temporarily widen a sync window (rare, requires platform-admin)

```bash
kubectl -n argocd edit appproject proj-applications
# add a temporary `kind: allow` window covering "now", or set manualSync: true
# (already true by default in this repo)
```

Revert this edit (or let it be overwritten by the next Git-sourced reconcile
if AppProjects were GitOps-managed — currently they are NOT, see
`bootstrap/scripts/03-bootstrap-root-app.sh`, applied manually) as soon as
the emergency window closes. Note in the incident channel that you did
this and when it was reverted.

## Mandatory post-break-glass steps

1. Open a PR reflecting the change in Git (if not already done as part of
   the fix itself).
2. Post in `#rhythmx-platform-alerts` (or the incident channel) what was
   changed, why, by whom, and the PR link.
3. Add a line to the incident post-mortem referencing this runbook and
   whether the runbook itself needs updating.
4. If Option C was used, confirm the AppProject's `syncWindows` in Git
   still matches what's live in the cluster (drift between the two is a
   known limitation since AppProjects aren't GitOps-managed post-bootstrap
   — see `docs/architecture/overview.md` and consider filing a follow-up to
   make `projects/` reconciled by its own Application, closing this gap).
