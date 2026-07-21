# Troubleshooting: Common Issues

## Kind cluster / bootstrap

### `kind create cluster` hangs or fails with "control-plane not ready"

- Check Docker has enough resources allocated (Docker Desktop: Settings ->
  Resources — at least 4 CPU / 6GB RAM recommended for the 3-node topology
  in `bootstrap/kind/kind-config.yaml`).
- `docker ps` — confirm 3 containers (`rhythmx-gitops-control-plane`,
  `rhythmx-gitops-worker`, `rhythmx-gitops-worker2`) are actually running.
- Retry with `kind delete cluster --name rhythmx-gitops` then re-run
  `01-create-kind-cluster.sh`.

### `platform.local` doesn't resolve / ingress unreachable

- Confirm `/etc/hosts` has `127.0.0.1 platform.local` (see
  `docs/operations/getting-started.md` step 7).
- Confirm the ingress-nginx controller pod is `Running`:
  `kubectl -n ingress-nginx get pods`.
- Confirm port 80/443 aren't already bound by something else on your host
  (`lsof -i :80`).

## Argo CD

### `helm upgrade --install` in `02-install-argocd.sh` times out

- Almost always insufficient cluster resources (see above) or a slow image
  pull on first run. Re-run the script — it's idempotent
  (`helm upgrade --install`).

### Application stuck `Unknown` / `ComparisonError` for `qa-*`/`prod-*`

- **Expected** on the single-cluster Kind sandbox — `qa`/`prod` clusters
  aren't provisioned/registered yet. See
  `docs/architecture/overview.md` "Cluster topology model". This is not a
  bug; it becomes healthy once those clusters exist and
  `clusters/qa/infrastructure/env.yaml` / `clusters/prod/infrastructure/env.yaml`'s
  `server:` field points at a real, registered cluster.

### `kustomize.buildOptions: --enable-helm` errors ("helm not found")

- The Argo CD `repo-server` pod needs `helm` on its `PATH`. The official
  `argo/argo-cd` chart's repo-server image bundles `helm` by default as of
  the pinned chart version (10.1.4) — if you've customized the repo-server
  image, confirm `helm version` works inside that image.

## Kyverno / policy

### A perfectly reasonable Deployment gets rejected

1. `kubectl get events -n <namespace> --field-selector reason=PolicyViolation`
   to identify which `ClusterPolicy` fired.
2. Read that policy's file under `policies/kyverno/policies/` for the exact
   pattern it enforces.
3. Fix the manifest, OR request a `PolicyException`
   (`policies/README.md` "Requesting a policy exception") if the policy is
   genuinely inapplicable to this workload.

### `disallow-latest-tag` rejects an image that clearly has a tag

- Check for a tag containing `latest` as a substring vs. exact match
  (the policy matches the exact tag value `latest`, not substrings) — if
  this is a false positive, file an issue; the policy's `foreach`/`image_info()`
  logic may need refinement for unusual registry path formats.

## External Secrets

### `ExternalSecret` stuck `SecretSyncedError`

```bash
kubectl describe externalsecret <name> -n <namespace>
```

- **Kubernetes provider (dev):** confirm the backing Secret actually exists
  in the `secrets-source` namespace (`kubectl get secret <name> -n secrets-source`)
  and that `eso-k8s-store-reader`'s RBAC Role/RoleBinding
  (`infrastructure/external-secrets/cluster-secret-store.yaml`) hasn't been
  accidentally modified.
- **Vault/Azure KV (qa/prod):** confirm the ESO ServiceAccount's Kubernetes
  auth role / Workload Identity federation is correctly configured on the
  secret manager side (outside this repo) — a `403`/`permission denied` in
  the ExternalSecret's status almost always means the secret manager side,
  not the `ExternalSecret` manifest, is misconfigured.

## Ingress / cert-manager

### `Certificate` stuck `False` / not issuing

```bash
kubectl describe certificate <name> -n <namespace>
kubectl describe certificaterequest -n <namespace>
kubectl describe order -n <namespace>       # ACME issuers only
kubectl describe challenge -n <namespace>   # ACME HTTP-01/DNS-01 issuers only
```

- **`selfsigned-issuer`:** should never fail — if it does, cert-manager
  itself is unhealthy (check `kubectl -n cert-manager get pods`).
- **`letsencrypt-staging`:** almost always an HTTP-01 challenge reachability
  issue — the domain must actually resolve to the ingress controller's
  public IP, and port 80 must be reachable from the internet (Let's
  Encrypt's validators, not just your machine). This will never succeed
  against `platform.local` on a local Kind sandbox — that ClusterIssuer is
  for real, publicly-resolvable qa/prod domains only.

## General GitOps drift

### "I `kubectl edit`'d something and it keeps reverting"

That's `selfHeal: true` working as intended (see
`docs/architecture/overview.md`) — Argo CD is GitOps-managed;
out-of-band edits are reverted to match Git on the next reconciliation.
Make the change in Git instead, or see `docs/runbooks/break-glass.md` if
this is a genuine emergency requiring a temporary manual state.
