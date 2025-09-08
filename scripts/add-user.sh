#!/usr/bin/env bash

# Script para criar um novo usuário, configurar o acesso via chave SSH
# e adicioná-lo a um grupo de deploy específico.
#
# Uso: sudo ./add_user.sh "nome_do_usuario" "chave_ssh_publica_completa"

# --- Configuração ---
# O grupo ao qual o novo usuário será adicionado. Altere se necessário.
DEPLOY_GROUP="camunda-deploy"

# --- Segurança e Robustez ---
# Sai imediatamente se um comando falhar (-e), se uma variável não definida for usada (-u),
# ou se um comando em um pipeline falhar (-o pipefail).
set -euo pipefail

# --- Funções de Log ---
log() {
  # O formato de data e hora é YYYY-MM-DD HH:MM:SS
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*"
}

die() {
  # Imprime uma mensagem de erro para a saída de erro padrão e sai.
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERRO] $*" >&2
  exit 1
}

# --- Verificações Iniciais ---

# 1. Checar se o script está sendo executado como root
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  die "Este script precisa ser executado com privilégios de root. Use 'sudo'."
fi

# 2. Checar se os dois argumentos foram fornecidos
if [[ $# -ne 2 ]]; then
  echo "Uso: sudo $0 \"nome_do_usuario\" \"chave_ssh_publica_completa\"" >&2
  echo "Exemplo: sudo $0 \"hugo\" \"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... hugo@macbook\"" >&2
  exit 1
fi

# --- Atribuição de Parâmetros ---
USERNAME="$1"
SSH_PUBLIC_KEY="$2"

# --- Validações ---

# 3. Checar se o usuário já existe
if id -u "$USERNAME" >/dev/null 2>&1; then
  die "O usuário '$USERNAME' já existe. Nenhuma ação foi tomada."
fi

# 4. Checar se o grupo de deploy existe
if ! getent group "$DEPLOY_GROUP" >/dev/null; then
  log "O grupo '$DEPLOY_GROUP' não existe. Criando..."
  groupadd "$DEPLOY_GROUP"
fi

# --- Execução Principal ---

log "Iniciando a configuração para o usuário: $USERNAME"

# 1. Criar o usuário com seu diretório home (-m) e shell padrão (-s)
log "Criando usuário '$USERNAME' com home em /home/$USERNAME..."
useradd -m -s /bin/bash "$USERNAME"

# 2. Configurar o diretório e o arquivo para a chave SSH
HOME_DIR="/home/$USERNAME"
SSH_DIR="$HOME_DIR/.ssh"
AUTHORIZED_KEYS_FILE="$SSH_DIR/authorized_keys"

log "Configurando diretório SSH em $SSH_DIR..."
mkdir -p "$SSH_DIR"

log "Adicionando chave pública ao arquivo $AUTHORIZED_KEYS_FILE..."
echo "$SSH_PUBLIC_KEY" >> "$AUTHORIZED_KEYS_FILE"

# 3. Ajustar permissões (passo crítico de segurança)
log "Ajustando permissões de segurança para os arquivos SSH..."
chown -R "$USERNAME:$USERNAME" "$SSH_DIR"
chmod 700 "$SSH_DIR"
chmod 600 "$AUTHORIZED_KEYS_FILE"

# 4. Adicionar usuário ao grupo de deploy
log "Adicionando usuário '$USERNAME' ao grupo '$DEPLOY_GROUP'..."
usermod -aG "$DEPLOY_GROUP" "$USERNAME"

# 5. Adicionar usuário ao grupo docker (para uso do Docker sem sudo)
#    Cria o grupo se não existir e adiciona o usuário.
if ! getent group docker >/dev/null; then
  log "O grupo 'docker' não existe. Criando..."
  groupadd docker
fi

log "Adicionando usuário '$USERNAME' ao grupo 'docker'..."
usermod -aG docker "$USERNAME"

log "---"
log "✅ Configuração concluída com sucesso para o usuário '$USERNAME'!"
log "Peça para que ele teste o acesso com o comando: ssh $USERNAME@<ip_do_servidor>"
log "Para usar Docker sem sudo, faça logout/login ou rode: newgrp docker"
log "Depois valide com: docker ps (deve listar sem pedir sudo)"
