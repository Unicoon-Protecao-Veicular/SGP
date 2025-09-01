#!/bin/bash
set -e

# Diretório base
BASE_DIR="/srv/camunda"

# --- Validação de Entrada ---
if [ -z "$1" ] || { [ "$1" != "dev" ] && [ "$1" != "staging" ]; }; then
    echo "Erro: Ambiente inválido. Especifique 'dev' ou 'staging'."
    echo "Uso: $0 {dev|staging}"
    exit 1
fi

ENV_TO_CONFIG="$1"
ENV_DIR="$BASE_DIR/$ENV_TO_CONFIG"

if [ ! -d "$ENV_DIR" ]; then
    echo "Erro: Diretório do ambiente '$ENV_DIR' não encontrado."
    exit 1
fi

# --- Configuração do Ambiente Específico ---
echo "Iniciando configuração para o ambiente: $ENV_TO_CONFIG"

CONFIG_FLAG_ENV="$ENV_DIR/.configured"

if [ -f "$CONFIG_FLAG_ENV" ]; then
    echo "Ambiente '$ENV_TO_CONFIG' já parece estar configurado. Pulando criação de arquivos de ambiente."
else
    echo "Configurando arquivos para '$ENV_TO_CONFIG'..."

    files_created=false
    # Copia .env se necessário
    if [ -f "$ENV_DIR/.env.example" ] && [ ! -f "$ENV_DIR/.env" ]; then
        cp "$ENV_DIR/.env.example" "$ENV_DIR/.env"
        echo "-> Criado '$ENV_DIR/.env'"
        files_created=true
    fi
    # Copia .web-modeler se necessário
    if [ -f "$ENV_DIR/.web-modeler.example" ] && [ ! -f "$ENV_DIR/.web-modeler" ]; then
        cp "$ENV_DIR/.web-modeler.example" "$ENV_DIR/.web-modeler"
        echo "-> Criado '$ENV_DIR/.web-modeler'"
        files_created=true
    fi

    if [ "$files_created" = true ]; then
        echo "AVISO: Edite os arquivos recém-criados em '$ENV_DIR' com as credenciais e configurações corretas."
    else
        echo "Nenhum arquivo de configuração novo foi criado (provavelmente já existiam)."
    fi

    # Marcar ambiente como configurado
    echo "Marcando ambiente '$ENV_TO_CONFIG' como configurado..."
    # Usando sudo -u como no script original, mas sem o '-i' que é desnecessário e pode causar problemas.
    # O usuário 'camunda-deploy' precisa ter permissão de escrita em $ENV_DIR.
    sudo -u camunda-deploy touch "$CONFIG_FLAG_ENV"
    echo "Configuração do ambiente '$ENV_TO_CONFIG' concluída."
fi

# --- Configuração Global do SystemD (executa apenas uma vez) ---
CONFIG_FLAG_SYSTEMD="$BASE_DIR/.systemd_configured"

if [ ! -f "$CONFIG_FLAG_SYSTEMD" ]; then
    echo "Realizando configuração do serviço SystemD (primeira execução)..."

    SERVICE_FILE="$BASE_DIR/systemd/camunda.service"
    if [ -f "$SERVICE_FILE" ]; then
        sudo cp "$SERVICE_FILE" /etc/systemd/system/
        sudo systemctl daemon-reload
        sudo systemctl enable camunda.service
        echo "-> Serviço 'camunda.service' copiado e habilitado."

        # Marcar como configurado
        sudo touch "$CONFIG_FLAG_SYSTEMD"
        echo "Configuração do SystemD concluída."
    else
        echo "AVISO: Arquivo de serviço '$SERVICE_FILE' não encontrado. Pulando configuração do SystemD."
    fi
else
    echo "Configuração do SystemD já foi realizada. Pulando."
fi

echo "Script finalizado."