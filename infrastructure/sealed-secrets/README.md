# sealed-secrets — NOT deployed on this platform (reference only)

This directory intentionally contains no Helm values, no Application, and
no live manifests. It exists to document a considered-and-rejected
alternative so the decision doesn't get re-litigated silently.

## Decision: External Secrets Operator (ESO) over Bitnami Sealed Secrets

| | Sealed Secrets | External Secrets Operator (chosen) |
|---|---|---|
| Secret source of truth | Git (encrypted `SealedSecret` CR) | External secret manager (Vault/cloud SM), Git holds only references |
| Rotation | Manual re-seal + commit on every rotation | Automatic via `refreshInterval`, zero Git churn |
| Blast radius of a leaked cluster key | Full historical secret archive in Git becomes decryptable | None — Git never contains secret material |
| Multi-cluster / DR | Re-seal per cluster (each has its own key) or shared key management overhead | Same external secret, same `ExternalSecret` manifest, any cluster |
| Audit trail | Git history only | External secret manager's own audit log (Vault audit device, CloudTrail, Azure Monitor) + Git history of *access* config |
| Fits existing secret manager investment | No (Sealed Secrets is its own silo) | Yes (Vault, AWS SM, Azure KV, GCP SM all supported) |

**Conclusion:** ESO's "Git holds config, not ciphertext" model has a
strictly better security posture for a platform that already assumes a
real secret manager exists in qa/prod (see
`docs/architecture/secrets-management.md`). Sealed Secrets remains a
reasonable choice for teams with NO external secret manager and a hard
requirement to keep everything in Git — reconsider only if that constraint
changes.

If a future requirement demands Sealed Secrets anyway (e.g. fully airgapped
cluster with no network path to any secret manager), re-open this decision
and populate this directory with the same layout as
`infrastructure/external-secrets/` (chart values + README + example CRs).
