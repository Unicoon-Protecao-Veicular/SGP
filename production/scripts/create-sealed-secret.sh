#!/bin/bash
# Script para gerar SealedSecrets do PostgreSQL, Keycloak Admin e Camunda Identity

set -e

echo "==> Verificando dependências..."
for bin in kubectl kubeseal; do
  if ! command -v $bin &>/dev/null; then
    echo "ERRO: $bin não encontrado. Instale e configure antes de prosseguir." >&2
    exit 1
  fi
done
echo "Ferramentas ok."

# --- Coleta de credenciais ---
echo ""
read -s -p "Digite a senha para o usuário admin do Keycloak: " KEYCLOAK_PASSWORD
echo
read -s -p "Confirme a senha do usuário admin do Keycloak: " KEYCLOAK_PASSWORD_CONFIRM
echo
[ "$KEYCLOAK_PASSWORD" != "$KEYCLOAK_PASSWORD_CONFIRM" ] && { echo "Senhas do Keycloak não coincidem."; exit 1; }

read -s -p "Digite a senha do superusuário PostgreSQL: " POSTGRES_PASSWORD
echo
read -s -p "Confirme a senha do superusuário PostgreSQL: " POSTGRES_PASSWORD_CONFIRM
echo
[ "$POSTGRES_PASSWORD" != "$POSTGRES_PASSWORD_CONFIRM" ] && { echo "Senhas do PostgreSQL não coincidem."; exit 1; }

read -s -p "Digite o client-secret do Identity (ou deixe em branco para gerar aleatório): " IDENTITY_SECRET
echo
if [ -z "$IDENTITY_SECRET" ]; then
  IDENTITY_SECRET=$(openssl rand -base64 32)
  echo "Client-secret do Identity gerado automaticamente."
fi

# --- Encode Base64 ---
KEYCLOAK_PASSWORD_B64=$(echo -n "$KEYCLOAK_PASSWORD" | base64)
POSTGRES_PASSWORD_B64=$(echo -n "$POSTGRES_PASSWORD" | base64)
IDENTITY_SECRET_B64=$(echo -n "$IDENTITY_SECRET" | base64)

# --- Diretórios ---
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
SECRETS_DIR="$SCRIPT_DIR/../k8s/secrets"
mkdir -p "$SECRETS_DIR"

# --- Arquivos temporários ---
TMP_POSTGRES=$(mktemp)
TMP_IDENTITY=$(mktemp)
TMP_KEYCLOAK=$(mktemp)

# --- Criar manifests temporários ---
cat > "$TMP_POSTGRES" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: postgresql-credentials
  namespace: camunda
type: Opaque
data:
  password: $KEYCLOAK_PASSWORD_B64
  postgres-password: $POSTGRES_PASSWORD_B64
EOF

cat > "$TMP_IDENTITY" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: camunda-platform-identity-secret
  namespace: camunda
type: Opaque
data:
  client-secret: $IDENTITY_SECRET_B64
EOF

cat > "$TMP_KEYCLOAK" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: camunda-platform-keycloak
  namespace: camunda
type: Opaque
data:
  admin-password: $KEYCLOAK_PASSWORD_B64
EOF

# --- Selar com kubeseal ---
echo "==> Selando segredos..."
kubeseal --controller-name sealed-secrets --format=yaml < "$TMP_POSTGRES" > "$SECRETS_DIR/sealed-postgresql-credentials.yaml"
kubeseal --controller-name sealed-secrets --format=yaml < "$TMP_IDENTITY" > "$SECRETS_DIR/sealed-identity-secret.yaml"
kubeseal --controller-name sealed-secrets --format=yaml < "$TMP_KEYCLOAK" > "$SECRETS_DIR/sealed-keycloak-admin.yaml"

# --- Limpeza ---
rm -f "$TMP_POSTGRES" "$TMP_IDENTITY" "$TMP_KEYCLOAK"

echo "==> SealedSecrets gerados em: $SECRETS_DIR"
ls -1 "$SECRETS_DIR"

echo ""
echo "Próximos passos:"
echo "1. Commit e push dos arquivos gerados no Git."
echo "2. Verifique se o values.yaml do Camunda aponta para o secret do Identity:"
echo "   identity.auth.existingSecret: camunda-platform-identity-secret"
echo "   identity.auth.existingSecretKey: client-secret"
echo "3. Só depois rode 'bash production/scripts/bootstrap-apps.sh'."
