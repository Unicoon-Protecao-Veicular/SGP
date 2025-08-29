#!/bin/bash
set -e

# Diretório do repositório
REPO_DIR="/srv/camunda"
LOG_FILE="/var/log/camunda-update.log"

# Executar como usuário de deploy
sudo -u camunda-deploy -i << EOF
cd "$REPO_DIR"

# Verificar atualizações
echo "[ \$(date) ] Verificando atualizações..." >> "$LOG_FILE"
git fetch origin

# Verificar se há mudanças
LOCAL=\$(git rev-parse @)
REMOTE=\$(git rev-parse @{u})

if [ "\$LOCAL" = "\$REMOTE" ]; then
    echo "[ \$(date) ] Nenhuma atualização disponível." >> "$LOG_FILE"
    exit 0
fi

# Fazer pull das atualizações
echo "[ \$(date) ] Atualizando repositório..." >> "$LOG_FILE"
git pull origin main
chmod +x scripts/config-camunda.sh

EOF

# Aplicar configurações
if [ -f "scripts/config-camunda.sh" ]; then
    echo "[ \$(date) ] Executando script de configuração..." >> "$LOG_FILE"
    ./scripts/config-camunda.sh
fi

echo "[ \$(date) ] Atualização concluída com sucesso!" >> "$LOG_FILE"


# Recarregar systemd se necessário
sudo systemctl daemon-reload

# Reiniciar serviços Camunda se configurado para auto-restart
if sudo systemctl is-active --quiet camunda.service; then
    echo "[ \$(date) ] Reiniciando serviço Camunda..." >> "$LOG_FILE"
    sudo systemctl restart camunda.service
fi