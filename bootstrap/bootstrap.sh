#!/usr/bin/env bash
# bootstrap.sh — installe ArgoCD sur aks-ops et enregistre les clusters demo
#
# Usage : bash bootstrap.sh <chemin-vers-fichier-cortex.values.yaml>
#
# Le fichier Cortex .values.yaml (généré depuis le portail Cortex) contient :
#   distribution.id    → ID unique par distribution / démo
#   dockerPullSecret   → clé GCP pour puller les images konnector
# Ces deux valeurs sont injectées comme annotations ArgoCD sur chaque cluster.
# Elles ne sont JAMAIS dans git.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
RESOURCE_GROUP="rg-cortex-demo"
ARGOCD_NAMESPACE="argocd"
ARGOCD_VERSION="7.8.0"     # Helm chart version (ArgoCD 2.13.x)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
die()  { echo -e "${RED}[✗]${NC} $*" >&2; exit 1; }

# ─── Paramètre : fichier Cortex .values.yaml ─────────────────────────────────
CORTEX_YAML="${1:-}"
[[ -z "$CORTEX_YAML" ]] && die "Usage : $0 <chemin-vers-fichier-cortex.values.yaml>"
[[ -f "$CORTEX_YAML" ]] || die "Fichier introuvable : $CORTEX_YAML"
CORTEX_YAML="$(realpath "$CORTEX_YAML")"

# Variables extraites du fichier Cortex (remplies par parse_cortex_yaml)
DIST_ID=""
DOCKER_PULL_SECRET=""

# ─── Extraction des valeurs depuis le fichier Cortex ─────────────────────────
parse_cortex_yaml() {
  log "Lecture du fichier Cortex : $CORTEX_YAML"

  if command -v yq &>/dev/null; then
    DIST_ID=$(yq '.distribution.id' "$CORTEX_YAML")
    DOCKER_PULL_SECRET=$(yq '.dockerPullSecret' "$CORTEX_YAML")
  else
    DIST_ID=$(python3 -c "
import yaml, sys
d = yaml.safe_load(open('$CORTEX_YAML'))
print(d['distribution']['id'])
")
    DOCKER_PULL_SECRET=$(python3 -c "
import yaml, sys
d = yaml.safe_load(open('$CORTEX_YAML'))
print(d['dockerPullSecret'])
")
  fi

  [[ -z "$DIST_ID" || "$DIST_ID" == "null" ]] && \
    die "distribution.id introuvable dans $CORTEX_YAML"
  [[ -z "$DOCKER_PULL_SECRET" || "$DOCKER_PULL_SECRET" == "null" ]] && \
    die "dockerPullSecret introuvable dans $CORTEX_YAML"

  log "Distribution ID    : $DIST_ID"
  log "dockerPullSecret   : ${DOCKER_PULL_SECRET:0:20}..."
}

# ─── Prérequis ───────────────────────────────────────────────────────────────
check_prereqs() {
  log "Vérification des prérequis..."
  for cmd in az kubectl helm argocd; do
    command -v "$cmd" &>/dev/null || die "Commande manquante : $cmd"
  done
  # yq ou python3 pour parser le YAML Cortex
  command -v yq &>/dev/null || \
    command -v python3 &>/dev/null || \
    die "yq ou python3 requis pour parser le fichier Cortex YAML"
  log "Tous les prérequis sont présents."
}

# ─── Kubeconfigs depuis Azure ─────────────────────────────────────────────────
get_kubeconfigs() {
  log "Récupération des kubeconfigs..."
  az aks get-credentials --resource-group "$RESOURCE_GROUP" --name aks-cortex-ops     --overwrite-existing
  az aks get-credentials --resource-group "$RESOURCE_GROUP" --name aks-cortex-demo-1  --overwrite-existing
  az aks get-credentials --resource-group "$RESOURCE_GROUP" --name aks-cortex-demo-2  --overwrite-existing
  az aks get-credentials --resource-group "$RESOURCE_GROUP" --name aks-cortex-demo-3  --overwrite-existing
  log "Kubeconfigs récupérés."
}

# ─── Installation ArgoCD ──────────────────────────────────────────────────────
install_argocd() {
  log "Installation d'ArgoCD sur aks-cortex-ops..."
  kubectl config use-context aks-cortex-ops

  helm repo add argo https://argoproj.github.io/argo-helm
  helm repo update

  helm upgrade --install argocd argo/argo-cd \
    --namespace "$ARGOCD_NAMESPACE" \
    --create-namespace \
    --version "$ARGOCD_VERSION" \
    --set server.service.type=LoadBalancer \
    --set configs.params."server\.insecure"=true \
    --wait --timeout 5m

  log "ArgoCD installé. Attente du LoadBalancer..."
  local argocd_ip=""
  while [[ -z "$argocd_ip" ]]; do
    argocd_ip=$(kubectl get svc argocd-server -n "$ARGOCD_NAMESPACE" \
      -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    [[ -z "$argocd_ip" ]] && sleep 5
  done
  log "ArgoCD UI accessible : http://$argocd_ip"
  echo "$argocd_ip" > "$SCRIPT_DIR/.argocd-ip"
}

# ─── Login ArgoCD CLI ─────────────────────────────────────────────────────────
login_argocd() {
  log "Login ArgoCD CLI..."
  local argocd_ip
  argocd_ip=$(cat "$SCRIPT_DIR/.argocd-ip")
  local argocd_password
  argocd_password=$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d)

  argocd login "$argocd_ip" \
    --username admin \
    --password "$argocd_password" \
    --insecure

  log "Login ArgoCD réussi. Mot de passe admin : $argocd_password"
  echo "ARGOCD_PASSWORD=$argocd_password" > "$SCRIPT_DIR/.argocd-credentials"
}

# ─── Enregistrement des clusters demo ────────────────────────────────────────
register_clusters() {
  log "Enregistrement des clusters demo dans ArgoCD..."

  for cluster in aks-cortex-demo-1 aks-cortex-demo-2 aks-cortex-demo-3; do
    # Enregistre le cluster, pose le label et les deux annotations en une commande
    argocd cluster add "$cluster" --yes \
      --label "cortex-enabled=true" \
      --annotation "cortex-distribution-id=$DIST_ID" \
      --annotation "cortex-docker-pull-secret=$DOCKER_PULL_SECRET"

    log "Cluster $cluster enregistré (dist-id=${DIST_ID:0:8}...)"
  done
}

# ─── Déploiement de l'ApplicationSet ─────────────────────────────────────────
deploy_applicationset() {
  log "Déploiement de l'ApplicationSet cortex-konnector..."
  kubectl config use-context aks-cortex-ops

  # Ajouter le repo Helm Palo Alto dans ArgoCD
  argocd repo add https://paloaltonetworks.github.io/cortex-cloud --type helm --name cortex

  # Appliquer l'ApplicationSet
  kubectl apply -f "$ROOT_DIR/gitops/argocd/applicationsets/cortex-konnector.yaml"

  log "ApplicationSet appliqué. ArgoCD va synchroniser les 3 clusters automatiquement."
  log "Vérifiez la progression : argocd app list"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  log "=== Bootstrap Cortex Demo ==="
  check_prereqs
  parse_cortex_yaml
  get_kubeconfigs
  install_argocd
  login_argocd
  register_clusters
  deploy_applicationset
  log "=== Bootstrap terminé ==="
  warn "Pensez à noter le mot de passe ArgoCD (stocké dans bootstrap/.argocd-credentials)"
}

main "$@"
