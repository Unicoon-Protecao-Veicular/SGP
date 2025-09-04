#!/usr/bin/env bash
set -euo pipefail

# Instala Longhorn via Helm (opcional, caso não use Argo CD para isso)
# Requisitos:
# - k3s/k8s acessível via kubectl
# - Helm instalado (production/scripts/bootstrap-helm.sh)

NAMESPACE="longhorn-system"
RELEASE="longhorn"
CHART_REPO_NAME="longhorn"
CHART_REPO_URL="https://charts.longhorn.io"
CHART_VERSION="1.6.2" # ajuste conforme necessário

echo "Adding Longhorn Helm repo..."
helm repo add "$CHART_REPO_NAME" "$CHART_REPO_URL" 2>/dev/null || true
helm repo update

echo "Creating namespace $NAMESPACE (if absent)..."
kubectl create namespace "$NAMESPACE" 2>/dev/null || true

echo "Installing/Upgrading Longhorn..."
helm upgrade --install "$RELEASE" "$CHART_REPO_NAME/longhorn" \
  --namespace "$NAMESPACE" \
  --version "$CHART_VERSION" \
  --set defaultSettings.defaultDataPath=/var/lib/longhorn \
  --set defaultSettings.defaultReplicaCount=1

echo "Longhorn installation triggered. Check status with: kubectl -n $NAMESPACE get pods"

