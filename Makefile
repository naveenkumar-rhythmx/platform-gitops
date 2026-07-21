SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

CLUSTER_NAME ?= rhythmx-gitops
ENVS := dev qa prod

.PHONY: help bootstrap create-cluster install-argocd bootstrap-root register-repos \
        validate lint kustomize-build kubeconform shellcheck \
        teardown clean status

help: ## Show this help
	@echo "platform-gitops — available targets:"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

## --- Bootstrap ------------------------------------------------------------

bootstrap: create-cluster install-argocd bootstrap-root ## Full Kind bootstrap: cluster -> Argo CD -> root app
	@echo "Bootstrap complete. See docs/operations/getting-started.md for next steps."

create-cluster: ## Create the Kind cluster (rhythmx-gitops)
	./bootstrap/scripts/01-create-kind-cluster.sh

install-argocd: ## Install Argo CD via Helm into the Kind cluster
	./bootstrap/scripts/02-install-argocd.sh

bootstrap-root: ## Apply AppProjects + the root Application (app-of-apps)
	./bootstrap/scripts/03-bootstrap-root-app.sh

register-repos: ## Register Git repositories with Argo CD (requires GIT_USERNAME/GIT_TOKEN env vars for private repos)
	./bootstrap/scripts/04-register-repos.sh

## --- Validation (mirrors .github/workflows/validate.yaml) ----------------

validate: lint kustomize-build kubeconform shellcheck ## Run all local validation checks

lint: ## Lint all YAML with yamllint
	yamllint -d "{extends: default, rules: {line-length: disable, document-start: disable, comments-indentation: disable}}" .

kustomize-build: ## kustomize build every clusters/<env>/{infrastructure,platform,apps} (requires --enable-helm network access)
	@for env in $(ENVS); do \
		for layer in infrastructure platform apps; do \
			echo "==> kustomize build --enable-helm clusters/$$env/$$layer"; \
			kustomize build --enable-helm --load-restrictor LoadRestrictionsNone "clusters/$$env/$$layer" > /dev/null || exit 1; \
		done; \
	done
	@echo "==> kustomize build projects"
	@kustomize build projects > /dev/null
	@echo "==> kustomize build app-of-apps"
	@kustomize build app-of-apps > /dev/null
	@echo "==> kustomize build policies/kyverno"
	@kustomize build policies/kyverno > /dev/null

kubeconform: ## Validate rendered manifests against Kubernetes schemas
	@for env in $(ENVS); do \
		for layer in infrastructure platform apps; do \
			echo "==> kubeconform clusters/$$env/$$layer"; \
			kustomize build --enable-helm --load-restrictor LoadRestrictionsNone "clusters/$$env/$$layer" \
				| kubeconform -strict -summary -ignore-missing-schemas -kubernetes-version 1.31.0; \
		done; \
	done

shellcheck: ## Shellcheck every bootstrap script
	shellcheck bootstrap/scripts/*.sh

## --- Cluster lifecycle -----------------------------------------------------

status: ## Show Argo CD Application status
	kubectl -n argocd get applications -o wide

teardown: ## Delete the Kind cluster (prompts for confirmation)
	./bootstrap/scripts/teardown.sh

clean: ## Delete the Kind cluster without confirmation (CI-safe)
	./bootstrap/scripts/teardown.sh --yes
