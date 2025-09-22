#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing Operator Lifecycle Manager (OLM)"

# Baixa e executa o script de instalação do OLM
# A versão pode ser atualizada conforme necessário. Consulte:
# https://github.com/operator-framework/operator-lifecycle-manager/releases
curl -sL https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.28.0/install.sh | bash -s v0.28.0

echo "--> Waiting for OLM to be ready..."

# Aguarda até que o deployment do olm-operator esteja disponível
kubectl wait --for=condition=Available -n olm deployment/olm-operator --timeout=120s

# Aguarda até que o deployment do catalog-operator esteja disponível
kubectl wait --for=condition=Available -n olm deployment/catalog-operator --timeout=120s

echo "OLM installed successfully."
