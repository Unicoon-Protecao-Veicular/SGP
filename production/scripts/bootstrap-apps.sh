#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

echo "Applying base namespaces..."
kubectl apply -f "$BASE_DIR/production/k8s/namespaces.yaml"

echo "Installing Argo CD project and app-of-apps..."
kubectl apply -f "$BASE_DIR/production/argocd/project.yaml"
kubectl apply -f "$BASE_DIR/production/argocd/app-of-apps.yaml"

echo "Done. Argo CD will now reconcile child apps (longhorn, ingress-nginx, monitoring, camunda)."
echo
echo "Aguarde alguns minutos para que os serviços principais sejam implantados pelo ArgoCD."
echo "Próximo passo: aplique os Ingresses da aplicação para expor os serviços:"
echo
echo "  kubectl apply -f production/k8s/ingress/"
echo
