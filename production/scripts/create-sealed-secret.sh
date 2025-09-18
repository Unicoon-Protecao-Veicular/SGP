#!/bin/bash

# Este script automatiza a criação de um SealedSecret para as credenciais do PostgreSQL.

set -e

# --- Verificação de Pré-requisitos ---
echo "Verificando se as ferramentas necessárias (kubectl, kubeseal) estão instaladas..."

if ! command -v kubectl &> /dev/null; then
    echo "ERRO: kubectl não encontrado. Por favor, instale-o e configure seu acesso ao cluster." >&2
    exit 1
fi

if ! command -v kubeseal &> /dev/null; then
    echo "ERRO: kubeseal não encontrado. Por favor, instale a CLI do Sealed Secrets." >&2
    exit 1
fi

echo "Ferramentas encontradas."

# --- Coleta de Senhas ---
echo ""

read -s -p "Digite a senha para o usuário do Keycloak (bn_keycloak): " KEYCLOAK_PASSWORD
echo
read -s -p "Confirme a senha do usuário do Keycloak: " KEYCLOAK_PASSWORD_CONFIRM
echo

if [ "$KEYCLOAK_PASSWORD" != "$KEYCLOAK_PASSWORD_CONFIRM" ]; then
    echo "ERRO: As senhas do Keycloak não coincidem." >&2
    exit 1
fi

read -s -p "Digite a senha para o superusuário do PostgreSQL (postgres): " POSTGRES_PASSWORD
echo
read -s -p "Confirme a senha do superusuário do PostgreSQL: " POSTGRES_PASSWORD_CONFIRM
echo

if [ "$POSTGRES_PASSWORD" != "$POSTGRES_PASSWORD_CONFIRM" ]; then
    echo "ERRO: As senhas do PostgreSQL não coincidem." >&2
    exit 1
fi

# --- Codificação e Geração do Secret ---

KEYCLOAK_PASSWORD_B64=$(echo -n "$KEYCLOAK_PASSWORD" | base64)
POSTGRES_PASSWORD_B64=$(echo -n "$POSTGRES_PASSWORD" | base64)

# Define o diretório de saída para estar no mesmo nível do diretório do script
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
SECRETS_DIR="$SCRIPT_DIR/../k8s/secrets"

TEMP_SECRET_FILE=$(mktemp)
SEALED_SECRET_FILE="$SECRETS_DIR/sealed-postgresql-credentials.yaml"

# Garante que o diretório de segredos exista
mkdir -p "$SECRETS_DIR"

cat > "$TEMP_SECRET_FILE" << EOF
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

# --- Criptografia com Kubeseal ---

echo ""
echo "Criando o secret temporário e tentando criptografá-lo com kubeseal..."
echo "Isso pode levar um momento, pois precisa contatar o controller no cluster."

if kubeseal --controller-name sealed-secrets --format=yaml < "$TEMP_SECRET_FILE" > "$SEALED_SECRET_FILE"; then
    echo ""
    echo "SUCESSO!" 
    echo "O arquivo criptografado foi salvo em: $SEALED_SECRET_FILE"
else
    echo ""
    echo "ERRO: A criptografia com kubeseal falhou." >&2
    echo "Verifique se o controller do Sealed Secrets está rodando no seu cluster e se seu kubectl está configurado corretamente." >&2
    rm -f "$TEMP_SECRET_FILE"
    exit 1
fi

# --- Limpeza ---

rm -f "$TEMP_SECRET_FILE"
echo "O arquivo de secret temporário foi removido com segurança."

# --- Próximos Passos ---

echo ""
echo "Próximos passos:"
echo "1. Faça o commit do arquivo '$SEALED_SECRET_FILE'."
echo "2. Execute 'bash production/scripts/bootstrap-apps.sh' para que o Argo CD instale todas as aplicações."
