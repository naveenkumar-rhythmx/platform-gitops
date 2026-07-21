# Secrets Management

## Decision: External Secrets Operator (ESO), backend varies by environment

| Environment | Backend | ClusterSecretStore |
|---|---|---|
| dev (Kind sandbox) | Kubernetes provider (in-cluster Secret in a `secrets-source` namespace) | `kubernetes-backend` — see `infrastructure/external-secrets/cluster-secret-store.yaml` |
| qa / prod (real clusters) | HashiCorp Vault (primary) or Azure Key Vault (alternative) | `vault-backend` / `azure-keyvault-backend` templates in the same file |

Git **never** contains secret material — only `ExternalSecret` manifests
that describe WHICH remote key maps to WHICH local `Secret`, refreshed on
an interval (`spec.refreshInterval`).

## Options considered

### External Secrets Operator (chosen)

- **Pros:** Git holds zero ciphertext or plaintext; rotation is automatic
  (`refreshInterval`, no re-commit needed); works identically across every
  provider (Kubernetes, Vault, AWS SM, Azure KV, GCP SM) — swapping backend
  later means changing the `ClusterSecretStore`, not every `ExternalSecret`;
  audit trail lives in the secret manager's own audit log, which is
  typically already SOC2/PCI-scoped.
- **Cons:** requires SOME external secret manager to exist (not zero-
  dependency like Sealed Secrets); an extra controller running in-cluster.

### Sealed Secrets (rejected — see `infrastructure/sealed-secrets/README.md`)

- **Pros:** zero external dependency, fully self-contained in Git.
- **Cons:** ciphertext lives in Git forever (rotation requires re-sealing +
  committing); a leaked cluster private key makes the FULL secret history
  in Git decryptable; multi-cluster/DR requires either shared key
  management or per-cluster re-sealing.
- **Verdict:** reasonable ONLY for teams with zero secret manager and a
  hard Git-only constraint. Not this platform's situation.

### HashiCorp Vault (qa/prod target backend)

- **Pros:** dynamic secrets (short-lived DB credentials), fine-grained
  policy, mature Kubernetes auth integration, industry-standard audit
  device.
- **Cons:** operational overhead of running/HA-ing Vault itself (or paying
  for HCP Vault); steeper initial setup than a cloud-native KV.
- **Fit:** primary target for qa/prod once a Vault cluster (self-hosted or
  HCP) is provisioned — see `cluster-secret-store.yaml`'s commented
  `vault-backend` template.

### AWS Secrets Manager / Azure Key Vault (cloud-native alternative)

- **Pros:** zero extra infrastructure to run/patch; native IAM/Workload
  Identity integration (no static credentials for ESO itself); built-in
  automatic rotation for supported secret types (RDS, etc.).
- **Cons:** cloud-provider lock-in for secret storage; typically no dynamic
  secrets the way Vault has.
- **Fit:** equally valid to Vault depending on which cloud the qa/prod
  clusters run on — `cluster-secret-store.yaml`'s `azure-keyvault-backend`
  template shows the Azure case using Workload Identity
  (`authType: WorkloadIdentity`); an AWS Secrets Manager provider follows
  the same shape with IRSA instead.

## Why Kind/dev uses the Kubernetes provider

The Kubernetes provider backend requires zero external services — it reads
another Secret on the SAME cluster (in a dedicated `secrets-source`
namespace with RBAC-restricted read-only access) — so the full
`ExternalSecret -> Secret` reconciliation loop can be demonstrated and
tested on a laptop Kind cluster with no Vault/cloud account required. It is
NOT intended for qa/prod (no dynamic secrets, no real separation of duties
between "who can read the secret manager" and "who can read Kubernetes
Secrets" — see `infrastructure/external-secrets/README.md`).

## Rotation

- **dev:** manual (`kubectl -n secrets-source create secret ... --dry-run
  -o yaml | kubectl apply -f -`, then wait for `refreshInterval`).
- **qa/prod:** rotation happens IN the secret manager (Vault dynamic
  secrets, or a scheduled rotation Lambda/Function for cloud KV) — ESO
  picks up the new value on the next `refreshInterval` tick with zero
  Kubernetes-side action required.

## What's explicitly OUT of scope for this repo

- The Vault/cloud KV cluster/instance itself is provisioned by
  infrastructure-as-code OUTSIDE this repo (this repo only configures the
  `ClusterSecretStore` pointing AT it).
- Break-glass access to the secret manager directly (bypassing ESO) is
  covered in `docs/runbooks/break-glass.md`.
