# Policies

Policy-as-code for the rhythmx-platform, enforced at admission time via
Kyverno (see `policies/gatekeeper/README.md` for why Gatekeeper/OPA is
reserved-but-unused). Owned by Security Architecture; Platform Engineering
co-maintains the wiring (kustomization, sync waves).

## Layout

| Path | Purpose |
|---|---|
| `kyverno/policies/*.yaml` | Individual `ClusterPolicy` objects |
| `kyverno/kustomization.yaml` | Aggregates policies, applied per-env via `clusters/<env>/platform/kustomization.yaml` |
| `gatekeeper/` | Decision record — not deployed |
| `pod-security/namespace-labels.yaml` | PSA labeling convention/guidance (labels themselves live on Namespace objects in `clusters/`) |
| `image-security/cosign-verify-policy.yaml` | Cosign/Sigstore image signature verification (Kyverno `verifyImages`) |

## Compliance control mapping

This mapping is a starting point for audit evidence collection, not a
substitute for a full control assessment. Update as policies are added.

| Control area | Framework reference (illustrative) | Enforced by |
|---|---|---|
| Least privilege / non-root containers | CIS Kubernetes Benchmark 5.2.6, SOC 2 CC6.1 | `kyverno/policies/require-non-root.yaml`, PSA `restricted` (`pod-security/namespace-labels.yaml`) |
| Immutable filesystem | CIS Kubernetes Benchmark 5.2.12 | `kyverno/policies/require-ro-rootfs.yaml` |
| Resource limits (availability / DoS protection) | CIS Kubernetes Benchmark 5.7.x, SOC 2 CC7.2 | `kyverno/policies/require-requests-limits.yaml`, `infrastructure/resource-quotas/` |
| Deterministic, auditable deployments | SOC 2 CC8.1 (change management) | `kyverno/policies/disallow-latest-tag.yaml` |
| Asset inventory / ownership traceability | SOC 2 CC6.1, ISO 27001 A.8.1 | `kyverno/policies/require-labels.yaml` |
| Network segmentation | CIS Kubernetes Benchmark 5.3.2, PCI DSS 1.3 | `infrastructure/network-policies/` (+ per-env instantiations) |
| Software supply chain integrity | SLSA, NIST SSDF PW.7/PW.9 | `image-security/cosign-verify-policy.yaml`, `docs/architecture/supply-chain-security.md` |
| Namespace isolation / admission baseline | CIS Kubernetes Benchmark 5.2.1-5.2.5 | `pod-security/namespace-labels.yaml` + PSA labels on every Namespace |
| Secrets never committed in plaintext | PCI DSS 3.x, SOC 2 CC6.1 | `infrastructure/external-secrets/`, `docs/architecture/secrets-management.md` |

## Enforcement posture by environment

All Kyverno policies in `kyverno/policies/` run with
`validationFailureAction: Enforce` (hard block) in every environment
EXCEPT `image-security/cosign-verify-policy.yaml`, which runs in `Audit`
mode platform-wide until 100% of org-built images are signed (see that
file's header comment and `docs/architecture/supply-chain-security.md`).

## Requesting a policy exception

Use Kyverno `PolicyException` resources (enabled via
`features.policyExceptions` in `clusters/<env>/platform/kyverno-values.yaml`),
scoped to the specific namespace + policy + resource name, with a comment
linking to the approving ticket. Do not disable a policy platform-wide to
unblock one workload.
