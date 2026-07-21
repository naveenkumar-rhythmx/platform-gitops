# Gatekeeper — reserved, not deployed (Kyverno is the platform's policy engine)

This directory intentionally contains no constraint templates, no
constraints, and no Application/Helm values. It exists to document a
considered-and-rejected default so the decision doesn't get re-litigated
silently, and to reserve the path if a future workload genuinely needs
OPA/Rego (e.g. a third-party integration that ships Gatekeeper
ConstraintTemplates out of the box).

## Decision: Kyverno over OPA/Gatekeeper

| | Kyverno (chosen) | Gatekeeper (OPA) |
|---|---|---|
| Policy language | Native Kubernetes YAML (patterns, overlays) | Rego (separate DSL, steeper learning curve) |
| Mutation support | Built-in (`mutate` rules) | Requires a separate mutating webhook mechanism |
| Image verification (Cosign) | Built-in `verifyImages` rule type | Requires external Rego + Cosign plugin wiring |
| Generate/cleanup resources | Built-in (`generate`, cleanup policies) | Not native; needs external controllers |
| Policy Reports | Built-in `PolicyReport`/`ClusterPolicyReport` CRDs | Requires `gatekeeper-status`/audit + manual reporting integration |
| Team familiarity (this org) | Higher — YAML-native, faster onboarding | Lower |

**Conclusion:** for a platform whose primary policy needs are validation +
mutation + image signature verification, expressed by engineers who
already read/write Kubernetes YAML all day, Kyverno's lower barrier to
entry and built-in `verifyImages` (used in
`policies/image-security/cosign-verify-policy.yaml`) make it the better
default. Gatekeeper/Rego remains a legitimate choice for teams with deep
existing OPA investment or policies that need Rego's more general
expressiveness (e.g. complex cross-resource correlation) — re-open this
decision if that need materializes.

If Gatekeeper is ever introduced, mirror the layout of `policies/kyverno/`
(policies/ subfolder + kustomization.yaml + README) rather than mixing
constraint templates directly into this stub.
