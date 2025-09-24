#!/usr/bin/env bash
set -euo pipefail

# Instala o cert-manager via Argo CD Application.
# Pré-requisitos: Argo CD já instalado e saudável.

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)

echo "[cert-manager] Aplicando Application do Argo CD..."
kubectl apply -f "$ROOT/production/argocd/apps/cert-manager.yaml"

echo "[cert-manager] Aguardando Deployments ficarem prontos..."
kubectl -n cert-manager rollout status deploy/cert-manager --timeout=180s || true
kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=180s || true
kubectl -n cert-manager rollout status deploy/cert-manager-cainjector --timeout=180s || true

echo "[cert-manager] Concluído. Prossiga criando os ClusterIssuers."

