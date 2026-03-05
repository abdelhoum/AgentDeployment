.PHONY: up down status argocd argocd-status tf-plan tf-apply tf-destroy help

RESOURCE_GROUP  := rg-cortex-demo
TF_DIR          := terraform
CORTEX_YAML     ?=

# ─── Infrastructure complète ──────────────────────────────────────────────────

## Lance tout : terraform + bootstrap (ArgoCD + clusters + ApplicationSet)
## Usage : make up CORTEX_YAML=./chemin/vers/client.values.yaml
up: tf-apply
	@[ -n "$(CORTEX_YAML)" ] || \
		(echo "" && \
		 echo "❌  Paramètre manquant : CORTEX_YAML" && \
		 echo "    Usage : make up CORTEX_YAML=./chemin/vers/client.values.yaml" && \
		 echo "" && \
		 exit 1)
	@echo ""
	@echo "Infrastructure créée. Lancement du bootstrap..."
	@bash bootstrap/bootstrap.sh "$(CORTEX_YAML)"
	@echo ""
	@echo "✓ Démo prête ! Clusters :"
	@$(MAKE) status

## Détruit tout (clusters AKS + resource group)
down: tf-destroy
	@echo "✓ Infrastructure détruite."

# ─── Terraform ────────────────────────────────────────────────────────────────

tf-init:
	cd $(TF_DIR) && terraform init

tf-plan: tf-init
	cd $(TF_DIR) && terraform plan

tf-apply: tf-init
	cd $(TF_DIR) && terraform apply -auto-approve

tf-destroy:
	cd $(TF_DIR) && terraform destroy -auto-approve

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
	@echo "Usage : make <cible>"
	@echo ""
	@echo "Infrastructure :"
	@echo "  up CORTEX_YAML=./client.values.yaml   Lance terraform + bootstrap"
	@echo "  down                                   Détruit toute l'infrastructure"
	@echo ""
	@echo "Suivi :"
	@echo "  status           Pods cortex sur les 3 clusters"
	@echo "  argocd-status    État des sync ArgoCD"
	@echo "  argocd           Port-forward UI ArgoCD (localhost:8080)"
	@echo ""
	@echo "Terraform direct :"
	@echo "  tf-plan          terraform plan"
	@echo "  tf-apply         terraform apply"
	@echo "  tf-destroy       terraform destroy"
