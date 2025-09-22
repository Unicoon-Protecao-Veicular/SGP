#!/bin/bash
# Script para gerar um SealedSecret para o Grafana.
# Gera uma senha aleatória para o usuário admin.

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
SECRET_NAME="grafana-admin"
NAMESPACE="monitoring"
SECRETS_DIR="$(cd "$(dirname "$0")/../k8s/secrets" && pwd)"
OUTPUT_FILE="$SECRETS_DIR/sealed-grafana-credentials.yaml"
TMP_SECRET_FILE=$(mktemp)

# Garante a limpeza do arquivo temporário ao sair
trap 'rm -f "$TMP_SECRET_FILE"' EXIT

# --- Geração de Senha Aleatória ---
log "Gerando senha segura e aleatória para o Grafana..."
GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 32)
log "Senha gerada com sucesso."

# --- Criação do Manifesto do Secret (em Base64) ---
cat > "$TMP_SECRET_FILE" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $SECRET_NAME
  namespace: $NAMESPACE
type: Opaque
data:
  admin-user: $(echo -n "admin" | base64)
  admin-password: $(echo -n "$GRAFANA_ADMIN_PASSWORD" | base64)
EOF

log "Manifesto do Secret temporário criado em $TMP_SECRET_FILE."

# --- Selar o Secret com kubeseal ---
log "Selando o secret com kubeseal..."
# O controller name deve corresponder ao nome do serviço do sealed-secrets no cluster
kubeseal --controller-name sealed-secrets --format=yaml < "$TMP_SECRET_FILE" > "$OUTPUT_FILE"

log "Sucesso! SealedSecret do Grafana gerado em:"
log "$OUTPUT_FILE"
echo ""
echo "Próximo passo: Faça o commit e push de '$OUTPUT_FILE' para seu repositório Git."