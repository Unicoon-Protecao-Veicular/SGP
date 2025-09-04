#!/usr/bin/env bash
set -euo pipefail

SECRET_NAME="sgp-repo-secret"
NAMESPACE="argocd"
REPO_URL="git@github.com:Unicoon-Protecao-Veicular/SGP.git"

log() {
  echo "==> [Argo CD Repo Config] $*"
}

# Verifica se o secret já existe para tornar o script idempotente
if kubectl -n "$NAMESPACE" get secret "$SECRET_NAME" >/dev/null 2>&1; then
  log "Secret de repositório '$SECRET_NAME' já existe. Nenhuma ação necessária."
  exit 0
fi

log "Secret de repositório não encontrado. Iniciando configuração..."

# Cria um par de chaves temporário
TMP_DIR=$(mktemp -d)
trap 'rm -rf -- "$TMP_DIR"' EXIT

SSH_KEY_PATH="$TMP_DIR/id_ed25519"
ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "argocd-sgp-production"

PRIVATE_KEY=$(cat "$SSH_KEY_PATH")
PUBLIC_KEY=$(cat "$SSH_KEY_PATH.pub")

log "Chave SSH gerada com sucesso."
echo "--------------------------------------------------------------------------------"
echo "AÇÃO NECESSÁRIA: Adicione a seguinte chave pública como uma 'Deploy Key' no seu repositório GitHub:"
echo "Repositório: https://github.com/Unicoon-Protecao-Veicular/SGP"
echo "Navegue para: Settings > Deploy Keys > Add deploy key"
echo "   - Title: Argo CD Production"
echo "   - Key:"
echo "$PUBLIC_KEY"
echo "   - NÃO marque 'Allow write access'."
echo "--------------------------------------------------------------------------------"
read -p "Pressione [Enter] para continuar após adicionar a chave ao GitHub..."

log "Criando o Secret '$SECRET_NAME' no namespace '$NAMESPACE'..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: $SECRET_NAME
  namespace: $NAMESPACE
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: $REPO_URL
  sshPrivateKey: |
$(sed 's/^/    /' "$SSH_KEY_PATH")
EOF

log "Secret de repositório configurado com sucesso!"