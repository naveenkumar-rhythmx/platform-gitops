# Getting Started

## Prerequisites

- Docker (or another Kind-compatible container runtime)
- [`kind`](https://kind.sigs.k8s.io/) >= 0.23
- `kubectl` >= 1.30
- `helm` >= 3.14
- `kustomize` (optional — `kubectl apply -k` bundles a compatible version,
  but the standalone CLI is more useful for `kustomize build` sanity checks)
- `git`

## 1. Clone the three repositories

```bash
git clone https://github.com/naveenkumar-rhythmx/platform-gitops.git
git clone https://github.com/naveenkumar-rhythmx/platform-helm-charts.git
git clone https://github.com/naveenkumar-rhythmx/application-config.git
cd platform-gitops
```

You only strictly need `platform-gitops` to bootstrap the sandbox — the
other two are cloned by Argo CD itself (via `git` under the hood) once
repos are registered in step 4.

## 2. Bootstrap the Kind cluster + Argo CD

```bash
./bootstrap/scripts/01-create-kind-cluster.sh
./bootstrap/scripts/02-install-argocd.sh
```

The second script prints the initial `admin` password. Save it, then
rotate/delete the secret as instructed in its output.

## 3. Access the Argo CD UI

```bash
kubectl -n argocd port-forward svc/argo-cd-argocd-server 8080:443
open https://localhost:8080   # login: admin / <password from step 2>
```

## 4. Register repositories (if any are private)

```bash
export GIT_USERNAME="svc-argocd-sync"
export GIT_TOKEN="<a real token, from your secret manager, never committed>"
./bootstrap/scripts/04-register-repos.sh
```

Skip this step if all three repos are public — Argo CD can clone
unauthenticated.

## 5. Bootstrap the root Application (app-of-apps)

```bash
./bootstrap/scripts/03-bootstrap-root-app.sh
```

This applies `projects/` (AppProjects) and `app-of-apps/` (the root
Application + three ApplicationSets). From here on, everything is
GitOps-managed — no more manual `kubectl apply`.

## 6. Watch reconciliation

```bash
kubectl -n argocd get applications -o wide -w
```

Expect, in order: `root-app` -> `dev-infrastructure` -> `dev-platform` ->
per-service `dev-<service>` Applications (the last group requires
`application-config` to actually have content under `apps/<service>/overlays/dev`
— see that repo's own getting-started docs).

`qa-infrastructure` / `prod-infrastructure` (and their `platform`/workload
counterparts) will show `Unknown`/`ComparisonError` until those clusters
exist and are registered — this is expected on a single-cluster Kind
sandbox; see `docs/architecture/overview.md` "Cluster topology model".

## 7. Reach ingress-nginx at platform.local

Add to `/etc/hosts`:

```
127.0.0.1 platform.local argocd.platform.local
```

Any `Ingress` using `platform.local` (or a subdomain) will resolve through
the Kind port mappings (80/443) configured in `bootstrap/kind/kind-config.yaml`.

## 8. Tear down

```bash
./bootstrap/scripts/teardown.sh --yes
```

Deletes the Kind cluster entirely. Nothing in Git is affected — re-run
steps 2-6 to rebuild from scratch (see `docs/architecture/disaster-recovery.md`).

## Next steps

- [Operations guide](operations-guide.md) — day-2 operational tasks
- [Runbooks](../runbooks/) — incident response procedures
- [Troubleshooting](../troubleshooting/common-issues.md)
