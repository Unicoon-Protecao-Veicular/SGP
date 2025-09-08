#!/bin/bash
set -e

# Diretório base
BASE_DIR="/srv/camunda"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

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

# --- Configuração de Certificado SSL (executa apenas uma vez) ---
# Observação: usamos diretórios específicos do ambiente (ex.: /srv/camunda/dev/data/certbot)
# para alinhar com os volumes definidos em dev/docker-compose.yaml (./data/certbot/...)
CERTBOT_FLAG="$BASE_DIR/.ssl_configured"
DOMAIN="dev.consultorunicoon.com.br"
CERTBOT_EMAIL="admin@consultorunicoon.com.br"
CERTBOT_BASE_DIR="$ENV_DIR/data/certbot"

if [ ! -f "$CERTBOT_FLAG" ]; then
    echo "Configurando certificado SSL com Certbot (primeira execução)..."
    mkdir -p "$CERTBOT_BASE_DIR/conf" "$CERTBOT_BASE_DIR/www"
    sudo docker run --rm --name certbot \
      -v "$CERTBOT_BASE_DIR/conf:/etc/letsencrypt" \
      -v "$CERTBOT_BASE_DIR/www:/var/www/certbot" \
      certbot/certbot certonly --webroot -w /var/www/certbot \
      -d "$DOMAIN" \
      --email "$CERTBOT_EMAIL" --agree-tos --noninteractive
    sudo touch "$CERTBOT_FLAG"
    echo "Certificado SSL configurado."
else
    echo "Certificado SSL já configurado. Pulando."
fi

# --- Configuração de CRON para renovação automática do certificado ---
CRON_FLAG="$BASE_DIR/.cron_ssl_configured"
DOCKER_BIN="$(command -v docker || echo /usr/bin/docker)"

if [ ! -f "$CRON_FLAG" ]; then
    echo "Configurando cron para renovação automática de certificados..."
    CRON_FILE="/etc/cron.d/certbot-renew-camunda"
    CRON_CONTENT=$(cat <<EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
# Renew Let's Encrypt certs and reload Nginx if changed
0 3 * * * root $DOCKER_BIN run --rm -v "$ENV_DIR/data/certbot/conf:/etc/letsencrypt" -v "$ENV_DIR/data/certbot/www:/var/www/certbot" certbot/certbot renew --quiet --no-self-upgrade && $DOCKER_BIN exec nginx nginx -s reload
EOF
)
    # Escrever arquivo de cron
    echo "$CRON_CONTENT" | sudo tee "$CRON_FILE" >/dev/null
    sudo chmod 644 "$CRON_FILE"
    # Aplicar alterações no cron (depende da distro; cron geralmente pega automaticamente, mas garantimos)
    if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl restart cron 2>/dev/null || sudo systemctl restart crond 2>/dev/null || true
    else
        sudo service cron restart 2>/dev/null || true
    fi
    sudo touch "$CRON_FLAG"
    echo "CRON configurado em $CRON_FILE."
else
    echo "CRON para renovação de certificados já configurado. Pulando."
fi

echo "Script finalizado."
