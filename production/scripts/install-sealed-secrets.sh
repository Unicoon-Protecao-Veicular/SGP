#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Instala o controller do Sealed Secrets para gerenciamento seguro de senhas
echo "==> Adicionando repositório Helm do Sealed Secrets..."
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update

echo "==> Instalando o chart do Sealed Secrets no namespace kube-system..."
helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system --create-namespace --wait

echo "==> Sealed Secrets instalado com sucesso."
