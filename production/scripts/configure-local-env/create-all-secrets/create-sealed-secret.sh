#!/bin/bash
# Script para gerar um SealedSecret consolidado para a plataforma Camunda.
# Gera senhas aleatórias para todos os componentes necessários.

set -euo pipefail

# --- Validações ---
log() { echo "==> $1"; }

if ! command -v kubeseal > /dev/null; then
  echo "ERRO: kubeseal não encontrado. Instale e configure-o para seu cluster." >&2
  exit 1
fi
if ! command -v openssl > /dev/null; then
  echo "ERRO: openssl não encontrado." >&2
  exit 1
fi
log "Dependências verificadas."

# --- Configurações ---
SECRET_NAME="camunda-credentials"
NAMESPACE="camunda"
SECRETS_DIR="$(cd "$(dirname "$0")/../../../k8s/secrets" && pwd)"
OUTPUT_FILE="$SECRETS_DIR/sealed-camunda-credentials.yaml"
TMP_SECRET_FILE=$(mktemp)

# Garante a limpeza do arquivo temporário ao sair
trap 'rm -f "$TMP_SECRET_FILE"' EXIT

# --- Geração de Senhas Aleatórias ---
log "Gerando senhas seguras e aleatórias..."
# Para o Keycloak Admin
KEYCLOAK_ADMIN_PASSWORD=$(openssl rand -base64 32)
# Para o Banco de Dados do Keycloak
KEYCLOAK_DB_PASSWORD=$(openssl rand -base64 32)

# Para os clients do Identity
IDENTITY_CLIENT_SECRET=$(openssl rand -base64 32)
OPERATE_CLIENT_SECRET=$(openssl rand -base64 32)
TASKLIST_CLIENT_SECRET=$(openssl rand -base64 32)
OPTIMIZE_CLIENT_SECRET=$(openssl rand -base64 32)
CONSOLE_CLIENT_SECRET=$(openssl rand -base64 32)
CONNECTORS_CLIENT_SECRET=$(openssl rand -base64 32)
ZEEBE_CLIENT_SECRET=$(openssl rand -base64 32)


log "Senhas geradas com sucesso."

# --- Criação do Manifesto do Secret (em Base64) ---
# O 'data' de um Secret precisa ter valores encodados em base64.
# O `echo -n` é crucial para não incluir um newline no valor.
cat > "$TMP_SECRET_FILE" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $SECRET_NAME
  namespace: $NAMESPACE
type: Opaque
data:
  # Credencial para o Admin do Keycloak (renomeado para clareza)
  keycloak-admin-password: $(echo -n "$KEYCLOAK_ADMIN_PASSWORD" | base64)

  # Credenciais para o Banco de Dados do Keycloak (exigido pelo Operator)
  keycloak-db-user: $(echo -n "keycloak" | base64)
  keycloak-db-password: $(echo -n "$KEYCLOAK_DB_PASSWORD" | base64)

  # Secrets para os clients do Camunda Identity
  client-secret: $(echo -n "$IDENTITY_CLIENT_SECRET" | base64)
  operate-secret: $(echo -n "$OPERATE_CLIENT_SECRET" | base64)
  tasklist-secret: $(echo -n "$TASKLIST_CLIENT_SECRET" | base64)
  optimize-secret: $(echo -n "$OPTIMIZE_CLIENT_SECRET" | base64)
  console-secret: $(echo -n "$CONSOLE_CLIENT_SECRET" | base64)
  connectors-secret: $(echo -n "$CONNECTORS_CLIENT_SECRET" | base64)
  zeebe-secret: $(echo -n "$ZEEBE_CLIENT_SECRET" | base64)
EOF

log "Manifesto do Secret temporário criado em $TMP_SECRET_FILE."

# --- Selar o Secret com kubeseal ---
log "Selando o secret com kubeseal..."
# O controller name deve corresponder ao nome do serviço do sealed-secrets no cluster
kubeseal --controller-name sealed-secrets --format=yaml < "$TMP_SECRET_FILE" > "$OUTPUT_FILE"

log "Sucesso! SealedSecret consolidado gerado em:"
log "$OUTPUT_FILE"
echo ""
echo "Próximo passo: Faça o commit e push de '$OUTPUT_FILE' para seu repositório Git."

# --- Criação do SealedSecret para o Keycloak ---
log "Gerando SealedSecret para o Keycloak..."

KEYCLOAK_SECRET_NAME="camunda-pg-cluster-pguser-keycloak"
KEYCLOAK_NAMESPACE="keycloak"
KEYCLOAK_OUTPUT_FILE="$SECRETS_DIR/sealed-keycloak-credentials.yaml"
KEYCLOAK_TMP_SECRET_FILE=$(mktemp)

# Garante a limpeza do arquivo temporário ao sair
trap 'rm -f "$KEYCLOAK_TMP_SECRET_FILE"' EXIT

# Reutiliza a senha do banco de dados do Keycloak gerada anteriormente
log "Utilizando a senha do banco de dados do Keycloak já gerada..."

cat > "$KEYCLOAK_TMP_SECRET_FILE" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $KEYCLOAK_SECRET_NAME
  namespace: $KEYCLOAK_NAMESPACE
type: Opaque
data:
  user: $(echo -n "keycloak" | base64)
  password: $(echo -n "$KEYCLOAK_DB_PASSWORD" | base64)
EOF

log "Manifesto do Secret temporário do Keycloak criado em $KEYCLOAK_TMP_SECRET_FILE."

log "Selando o secret do Keycloak com kubeseal..."
kubeseal --controller-name sealed-secrets --format=yaml < "$KEYCLOAK_TMP_SECRET_FILE" > "$KEYCLOAK_OUTPUT_FILE"

log "Sucesso! SealedSecret do Keycloak gerado em:"
log "$KEYCLOAK_OUTPUT_FILE"
