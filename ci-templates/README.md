# CI templates

Copy `github-actions-app-ci.yaml` into each application source repository as `.github/workflows/ci.yaml`.

Required secrets on app repos:
- `PLATFORM_GITOPS_TOKEN` — fine-grained PAT or GitHub App with `contents:write` + `workflows` on `application-config` for `repository_dispatch`.

This implements SLSA-oriented practices: provenance from buildx, SBOM, Trivy gates, Cosign keyless signing, and GitOps digest bump via bot — not kubectl from CI.
