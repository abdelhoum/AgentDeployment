.PHONY: up down status argocd argocd-status tf-plan tf-apply tf-destroy help
SHELL := /bin/bash

RESOURCE_GROUP  := rg-cortex-demo
TF_DIR          := terraform
CORTEX_YAML     ?=
SUBSCRIPTION_ID ?=

# ─── Validation des paramètres ────────────────────────────────────────────────

check-params:
	@[ -n "$(SUBSCRIPTION_ID)" ] || \
		(echo "" && \
		 echo "❌  Paramètre manquant : SUBSCRIPTION_ID" && \
		 echo "    Usage : make $(MAKECMDGOALS) SUBSCRIPTION_ID=xxxx-xxxx-xxxx ..." && \
		 echo "" && exit 1)

check-all: check-params
	@[ -n "$(CORTEX_YAML)" ] || \
		(echo "" && \
		 echo "❌  Paramètre manquant : CORTEX_YAML" && \
		 echo "    Usage : make up SUBSCRIPTION_ID=xxxx CORTEX_YAML=./client.values.yaml" && \
		 echo "" && exit 1)
	@[ -f "$(CORTEX_YAML)" ] || \
		(echo "❌  Fichier introuvable : $(CORTEX_YAML)" && exit 1)

# ─── Infrastructure complète ──────────────────────────────────────────────────

## Lance tout : terraform + bootstrap (ArgoCD + clusters + ApplicationSet)
## Usage : make up SUBSCRIPTION_ID=xxxx CORTEX_YAML=./client.values.yaml
up: check-all tf-apply
	@echo ""
	@echo "Infrastructure créée. Lancement du bootstrap..."
	@bash bootstrap/bootstrap.sh "$(CORTEX_YAML)"
	@echo ""
	@echo "✓ Démo prête ! Clusters :"
	@$(MAKE) status

## Détruit tout (clusters AKS + resource group)
## Usage : make down SUBSCRIPTION_ID=xxxx
down: check-params tf-destroy
	@echo "✓ Infrastructure détruite."

# ─── Terraform ────────────────────────────────────────────────────────────────

tf-init:
	cd $(TF_DIR) && terraform init

tf-plan: check-params tf-init
	cd $(TF_DIR) && terraform plan -var="subscription_id=$(SUBSCRIPTION_ID)"

tf-apply: tf-init
	cd $(TF_DIR) && terraform apply -auto-approve -var="subscription_id=$(SUBSCRIPTION_ID)"

tf-destroy:
	cd $(TF_DIR) && terraform destroy -auto-approve -var="subscription_id=$(SUBSCRIPTION_ID)"

# ─── Status ───────────────────────────────────────────────────────────────────

## Affiche les pods cortex sur les 3 clusters demo
status:
	@for cluster in aks-cortex-demo-1 aks-cortex-demo-2 aks-cortex-demo-3; do \
		echo ""; \
		echo "=== $$cluster ==="; \
		kubectl get pods -n panw --context=$$cluster 2>/dev/null || echo "  (namespace panw non trouvé)"; \
	done

## Affiche l'état des Applications ArgoCD
argocd-status:
	@kubectl config use-context aks-cortex-ops
	@argocd app list

# ─── ArgoCD UI ────────────────────────────────────────────────────────────────

## Ouvre un port-forward vers l'UI ArgoCD (http://localhost:8080)
argocd:
	@kubectl config use-context aks-cortex-ops
	@echo "ArgoCD UI : http://localhost:8080"
	@echo "Mot de passe : $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
	@kubectl port-forward svc/argocd-server -n argocd 8080:80

# ─── Aide ─────────────────────────────────────────────────────────────────────

help:
	@echo "Usage : make <cible> SUBSCRIPTION_ID=xxxx [CORTEX_YAML=./client.values.yaml]"
	@echo ""
	@echo "Infrastructure :"
	@echo "  up   SUBSCRIPTION_ID=xxxx CORTEX_YAML=./client.values.yaml"
	@echo "  down SUBSCRIPTION_ID=xxxx"
	@echo ""
	@echo "Suivi :"
	@echo "  status           Pods cortex sur les 3 clusters"
	@echo "  argocd-status    État des sync ArgoCD"
	@echo "  argocd           Port-forward UI ArgoCD (localhost:8080)"
	@echo ""
	@echo "Terraform direct :"
	@echo "  tf-plan  SUBSCRIPTION_ID=xxxx"
	@echo "  tf-apply SUBSCRIPTION_ID=xxxx"
