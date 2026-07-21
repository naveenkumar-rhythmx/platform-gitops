# platform-gitops

> Enterprise GitOps control plane for `rhythmx-platform` — Argo CD App-of-Apps, cluster topology, platform infrastructure, and policy-as-code.

**Organization:** [naveenkumar-rhythmx](https://github.com/naveenkumar-rhythmx)  
**Owners:** Platform Engineering (primary), SRE (shared), Security Architecture (policies)  
**Consumers:** Application teams via ApplicationSets; Release Engineering for promotions

---

## Why this repository exists

In Fortune 500 platform orgs, **desired cluster state is separated from application source and Helm chart packaging**:

| Concern | Repository | Rationale |
|---------|------------|-----------|
| Cluster desired state & Argo CD | **platform-gitops** (this repo) | Single source of truth for *what runs where*; blast-radius isolation from app code |
| Chart packaging | `platform-helm-charts` | Versioned, reusable OCI charts; chart PRs ≠ deploy PRs |
| Env overlays / image tags | `application-config` | Promotion without rebuilding charts; audit trail for prod changes |
| Application source | `user-service`, `order-service`, … | Independent CI, ownership, and release cadence |

This follows **GitOps principles** (declarative, versioned, pulled, continuously reconciled) and CNCF GitOps Working Group recommendations.

---

## Ownership & RACI

| Area | Accountable | Responsible | Consulted | Informed |
|------|-------------|-------------|-----------|----------|
| Argo CD / App-of-Apps | Platform Eng | Platform Eng | SRE, Security | App teams |
| Cluster bootstrap (Kind/prod) | Platform Eng | Platform Eng | SRE | All |
| Infrastructure addons | Platform Eng | Platform Eng | SRE | App teams |
| Kyverno / PSS policies | Security Arch | Platform Eng | Compliance | App teams |
| Workload ApplicationSets | Platform Eng | Platform Eng | App teams | SRE |
| Sync windows / prod freezes | SRE | Platform Eng | Release Eng | All |

---

## Branching strategy

| Branch | Purpose | Protection |
|--------|---------|------------|
| `main` | Production-ready desired state | Required reviews (2), CODEOWNERS, status checks, no force-push |
| `env/dev` | Optional long-lived for aggressive experimentation | Soft protection |
| `env/qa` | QA freeze / hotfix staging | Soft protection |
| `release/*` | Coordinated platform releases | Tagged after merge to main |
| `feature/*`, `fix/*` | Short-lived | PR → main only |

**Rule:** Never push directly to `main`. All cluster mutations flow through PR + CI validation (`kubeconform`, `helm lint` via referenced charts, policy dry-run).

---

## Release strategy

- **Platform release cadence:** bi-weekly tagged releases (`platform-vX.Y.Z`)
- **Infra chart bumps:** PR updates pin in `clusters/*/infrastructure/`
- **Argo CD itself:** GitOps-managed after bootstrap; upgrades via version pin + sync wave 0
- **Emergency:** break-glass documented in `docs/runbooks/break-glass.md` (time-boxed, audited)

---

## Promotion strategy (cross-repo)

```
Developer → PR (app source) → CI (build/test/scan/SBOM/sign)
  → Image + Chart version
  → application-config overlay:dev (auto / bot PR)
  → Argo CD syncs Dev
  → QA approval → overlay:qa
  → Production CAB / Environment protection → overlay:prod
  → Argo CD syncs Prod (sync window)
```

This repo **does not** hold image digests for apps; it references `application-config` and Helm OCI versions. Infrastructure versions are pinned here.

---

## Repository layout

```
platform-gitops/
├── argocd/                 # Argo CD install values, RBAC, notifications
├── app-of-apps/            # Root Application(s) that spawn everything
├── applications/           # Static Application manifests (reference / overrides)
├── projects/               # AppProject isolation (infra / platform / apps)
├── bootstrap/              # Kind cluster + first Argo CD install (chicken/egg)
├── clusters/
│   ├── dev/
│   ├── qa/
│   └── prod/
├── infrastructure/         # Shared Helm/Kustomize defs for addons
├── policies/               # Kyverno, Gatekeeper stubs, PSS, network
├── docs/                   # Architecture, runbooks, ops, troubleshooting
└── .github/workflows/      # Validate, drift detect, promote helpers
```

---

## Quick start (Kind)

```bash
# 1. Prerequisites: docker, kind, kubectl, helm, git
./bootstrap/scripts/01-create-kind-cluster.sh
./bootstrap/scripts/02-install-argocd.sh
./bootstrap/scripts/03-bootstrap-root-app.sh

# 2. Access Argo CD UI
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
kubectl -n argocd port-forward svc/argocd-server 8080:443

# 3. Tear down
./bootstrap/scripts/teardown.sh
```

Or via `make`: `make bootstrap`, `make validate`, `make teardown` — see [`Makefile`](Makefile) (`make help` for the full target list).

See [docs/operations/getting-started.md](docs/operations/getting-started.md).

---

## Naming conventions

| Object | Pattern | Example |
|--------|---------|---------|
| Namespace | `{layer}-{name}-{env}` or platform short | `apps-user-dev`, `platform-monitoring` |
| Argo Application | `{env}-{component}` | `dev-ingress-nginx` |
| AppProject | `proj-{domain}` | `proj-infrastructure` |
| Cluster label | `platform.rhythmx.io/environment` | `dev` / `qa` / `prod` |

Kubernetes recommended labels are mandatory on all owned resources.

---

## Version pins & further reading

- [`VERSIONS.md`](VERSIONS.md) — authoritative chart/app version ledger (Argo CD, ingress-nginx, cert-manager, external-secrets, kyverno, metrics-server).
- [`docs/DIRECTORY_TREE.md`](docs/DIRECTORY_TREE.md) — annotated full repository layout.
- [`docs/architecture/`](docs/architecture/) — overview, repo strategy, promotion flow, deployment strategies, secrets management, autoscaling, disaster recovery, supply chain security, naming standards.
- [`docs/operations/`](docs/operations/) — getting started, day-2 operations guide.
- [`docs/runbooks/`](docs/runbooks/) — Argo CD outage, failed sync, break-glass.
- [`docs/troubleshooting/common-issues.md`](docs/troubleshooting/common-issues.md).
- [`policies/README.md`](policies/README.md) — compliance control mapping.

## Related repositories

- https://github.com/naveenkumar-rhythmx/platform-helm-charts
- https://github.com/naveenkumar-rhythmx/application-config
- https://github.com/naveenkumar-rhythmx/user-service
- https://github.com/naveenkumar-rhythmx/order-service
- https://github.com/naveenkumar-rhythmx/inventory-service

---

## License

Internal platform blueprint — adapt for your organization.
