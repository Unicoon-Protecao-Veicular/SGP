#!/bin/bash
set -e

# Diretório base
BASE_DIR="/srv/camunda"

# Verificar se é a primeira execução
if [ ! -f "$BASE_DIR/.configured" ]; then
    echo "Configuração inicial detectada..."
    
    # Criar arquivos de ambiente a partir dos exemplos
    for env in dev staging; do
        if [ -f "$BASE_DIR/$env/.env.example" ] && [ ! -f "$BASE_DIR/$env/.env" ]; then
            cp "$BASE_DIR/$env/.env.example" "$BASE_DIR/$env/.env"
            echo "Arquivo $env/.env criado. Por favor, edite com as credenciais corretas."
        fi
    done
    
    # Configurar systemd
    sudo cp "$BASE_DIR/systemd/camunda.service" /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable camunda.service
    sudo -u camunda-deploy -i << EOF
    # Marcar como configurado
    touch "$BASE_DIR/.configured"
    echo "Configuração inicial concluída!"
    
EOF
fi