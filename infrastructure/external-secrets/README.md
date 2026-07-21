# external-secrets (ESO)

Upstream chart: [`external-secrets/external-secrets`](https://github.com/external-secrets/external-secrets) via `https://charts.external-secrets.io`.

| | |
|---|---|
| Chart version (pinned) | `2.8.0` |
| Namespace | `external-secrets` |
| CRDs | `ExternalSecret`, `SecretStore`, `ClusterSecretStore`, `PushSecret`, `ClusterExternalSecret` |

See `docs/architecture/secrets-management.md` for the full comparison of
ESO vs. Sealed Secrets vs. HashiCorp Vault vs. AWS Secrets Manager vs.
Azure Key Vault, and why ESO is the platform default.

## Consumption paths

Same dual-path pattern as `infrastructure/ingress-nginx/` — see that
directory's README.

## SecretStore backends

- `cluster-secret-store.yaml` in this directory implements a **Kubernetes
  provider** `ClusterSecretStore` — sources "external" secrets from Secrets
  in a designated source namespace on the SAME cluster. This has no
  external dependency and is exactly what a Kind sandbox needs to
  demonstrate the full ExternalSecret -> Secret reconciliation flow without
  a real secret manager.
- `external-secret-examples.yaml` shows 3 `ExternalSecret` objects pulling
  from that store, PLUS commented-out equivalents for HashiCorp Vault and
  Azure Key Vault providers (the two real backends this platform expects to
  use in qa/prod — see secrets-management.md for the decision record).

## Notable values knobs

- `webhook.port` / `certController.enabled` — leave chart defaults (webhook
  cert managed by ESO's own cert-controller by default; can be swapped to
  cert-manager via `certController.certManager.enabled: true` if preferred).
- `concurrent` — number of concurrent secret reconciles; bumped in prod.
