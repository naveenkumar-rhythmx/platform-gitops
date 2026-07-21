# Runbook: Failed Sync

## Symptoms

- An Application shows `SYNC STATUS: OutOfSync` persistently (not just
  transiently after a push) or `Health: Degraded`.
- A Slack alert fires in `#rhythmx-platform-alerts` from the
  `on-sync-failed` or `on-health-degraded` trigger
  (`argocd/notifications/config.yaml`).

## Triage

```bash
argocd app get <app-name>
# or
kubectl -n argocd describe application <app-name>
```

Look at `status.conditions` and `status.operationState.message` for the
specific error. Common categories:

### 1. Manifest render error (kustomize/helm)

```
message: "rpc error: ... failed to generate manifest for source ..."
```

Reproduce locally:

```bash
kustomize build --enable-helm clusters/dev/infrastructure
```

Fix the underlying kustomization/values file, commit, push — Argo CD
retries automatically (`syncPolicy.retry`, exponential backoff, see the
Application/ApplicationSet's `retry.backoff` block).

### 2. Admission webhook rejection

```
message: "admission webhook \"validate.kyverno.svc-fail\" denied the request"
```

A Kyverno policy blocked the resource. Check which policy:

```bash
kubectl get events -n <target-namespace> --field-selector reason=PolicyViolation
kubectl get policyreport -n <target-namespace> -o wide
```

Either fix the manifest to comply, or — if the policy itself is wrong for
this legitimate case — request a scoped `PolicyException` (see
`policies/README.md` "Requesting a policy exception"). Do NOT disable the
policy platform-wide.

### 3. AppProject destination/resource denial

```
message: "... application repo ... is not permitted in project '...'"
```

The Application's source repo, destination namespace, or resource kind
isn't in the relevant `projects/proj-*.yaml`'s whitelist. Fix by updating
that AppProject (requires Platform Engineering review per `CODEOWNERS`) —
never by moving the Application to a more permissive project as a
workaround.

### 4. Sync window closed

```
message: "... blocked by sync window"
```

Expected behavior for `prod-*` Applications outside
Mon-Thu 10:00-16:00 UTC (`projects/proj-applications.yaml`) or outside
business hours for infra/platform (`proj-infrastructure.yaml`/`proj-platform.yaml`).
Wait for the window, or follow `docs/runbooks/break-glass.md` if urgent.

### 5. Resource stuck (finalizer, drift from manual `kubectl edit`)

```bash
kubectl -n <ns> get <kind> <name> -o yaml | grep -A5 finalizers
```

If a manual out-of-band change caused drift and `selfHeal: true` isn't
correcting it, check for a stuck finalizer blocking deletion/replacement,
or a field owned by a controller outside Argo CD's `ignoreDifferences`
list (add the field to that Application/ApplicationSet's
`ignoreDifferences` if it's legitimately controller-owned, e.g. HPA-managed
replica counts).

## Escalation

If the fix requires disabling `selfHeal`/`automated` sync temporarily to
stop a fight between Argo CD and another controller while investigating:

```bash
kubectl -n argocd patch application <app-name> --type merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}'
```

Re-enable (`syncPolicy.automated: {prune: true, selfHeal: true}`) once
resolved — do not leave automated sync permanently disabled without
updating the source Application/ApplicationSet manifest in Git to match
(otherwise the next reconciliation of the *ApplicationSet* re-enables it
anyway, and the live state silently diverges from Git in the meantime).
