#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "Applying base namespaces..."
kubectl apply -f "$BASE_DIR/production/k8s/namespaces.yaml"

echo "Installing Argo CD project and app-of-apps..."
kubectl apply -f "$BASE_DIR/production/argocd/project.yaml"
kubectl apply -f "$BASE_DIR/production/argocd/app-of-apps.yaml"

echo "Done. Argo CD will now reconcile child apps (longhorn, ingress-nginx, monitoring, camunda)."
