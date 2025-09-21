#!/usr/bin/env bash
set -euo pipefail

# Bootstrap do usuário e ambiente de deploy do Camunda
# - Cria o usuário/grupo camunda-deploy
# - Gera par de chaves SSH (ed25519) e configura ~/.ssh/config
# - (Opcional) Clona o repositório com as configurações em /srv/camunda
# - Ajusta permissões e ACLs
# - (Opcional) Adiciona usuários ao grupo camunda-deploy
#
# Uso básico:
#   sudo bash scripts/bootstrap-camunda-deploy.sh \
#     --repo git@github.com:seu-usuario/camunda-config.git \
#     [--target-dir /srv/camunda] [--key-name camunda-deploy] \
#     [--add-user usuario1 --add-user usuario2]
#
# Requisitos:
# - Executar como root (ou via sudo)
# - O script instalará automaticamente os pacotes: git, openssh-client, acl

DEPLOY_USER=${DEPLOY_USER:-camunda-deploy}
DEPLOY_GROUP=${DEPLOY_GROUP:-camunda-deploy}
TARGET_DIR=${TARGET_DIR:-/srv/camunda}
KEY_NAME=${KEY_NAME:-camunda-deploy}
REPO_SSH_URL=""
GIT_BRANCH=""
GIT_NAME=${GIT_NAME:-"Camunda Deploy"}
GIT_EMAIL=${GIT_EMAIL:-"camunda-deploy@$(hostname -f 2>/dev/null || hostname)"}
ADD_USERS=()

log() { echo "[bootstrap] $*"; }
warn() { echo "[bootstrap][WARN] $*" >&2; }
die() { echo "[bootstrap][ERROR] $*" >&2; exit 1; }

usage() {
  cat <<EOF
Uso: sudo bash $0 --repo <ssh_url> [opções]

Opções:
  --repo <ssh_url>         URL SSH do repositório (ex.: git@github.com:org/repo.git)
  --branch <branch>        Branch a ser clonada (padrão: branch default do repositório)
  --target-dir <dir>       Diretório de destino do clone (padrão: /srv/camunda)
  --key-name <nome>        Nome base do par de chaves em ~/.ssh (padrão: camunda-deploy)
  --git-name <nome>        Nome do usuário Git local no repositório (padrão: Camunda Deploy)
  --git-email <email>      Email do usuário Git local (padrão: camunda-deploy@<host>)
  --add-user <usuario>     Adiciona um usuário existente ao grupo camunda-deploy (pode repetir)
  -h | --help              Mostra esta ajuda

Exemplo:
  sudo bash $0 \
    --repo git@github.com:seu-usuario/camunda-config.git \
    --branch main \
    --add-user usuario1 --add-user usuario2
EOF
}

# ---- Parse args ----
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO_SSH_URL=${2:-}; shift 2 || true ;;
    --branch)
      GIT_BRANCH=${2:-}; shift 2 || true ;;
    --target-dir)
      TARGET_DIR=${2:-}; shift 2 || true ;;
    --key-name)
      KEY_NAME=${2:-}; shift 2 || true ;;
    --git-name)
      GIT_NAME=${2:-}; shift 2 || true ;;
    --git-email)
      GIT_EMAIL=${2:-}; shift 2 || true ;;
    --add-user)
      ADD_USERS+=("${2:-}"); shift 2 || true ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      warn "Argumento desconhecido: $1"; usage; exit 2 ;;
  esac
done


# ---- Função para instalar dependências ----
install_dependencies() {
  log "Verificando e instalando dependências (git, openssh-client, acl)..."
  if ! command -v apt-get >/dev/null; then
    warn "Gerenciador de pacotes 'apt-get' não encontrado. Pulando instalação de dependências."
    return
  fi
  # Atualiza a lista de pacotes apenas se necessário (evita lentidão)
  if [ -z "$(find /var/lib/apt/lists -maxdepth 1 -mmin -60)" ]; then
    apt-get update -y
  fi
  apt-get install -y git openssh-client acl
}

# ---- Root check ----
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  die "Execute como root (use sudo)."
fi

# ---- Dependências básicas ----
command -v git >/dev/null 2>&1 || warn "git não encontrado. Instale para permitir o clone."
install_dependencies

# ---- Garantir grupo e usuário ----
if ! getent group "$DEPLOY_GROUP" >/dev/null; then
  log "Criando grupo: $DEPLOY_GROUP"
  groupadd "$DEPLOY_GROUP"
else
  log "Grupo já existe: $DEPLOY_GROUP"
fi

if ! id -u "$DEPLOY_USER" >/dev/null 2>&1; then
  log "Criando usuário: $DEPLOY_USER"
  useradd -m -s /bin/bash -g "$DEPLOY_GROUP" "$DEPLOY_USER"
else
  log "Usuário já existe: $DEPLOY_USER"
fi

DEPLOY_HOME=$(getent passwd "$DEPLOY_USER" | cut -d: -f6)
[[ -n "$DEPLOY_HOME" ]] || die "Não foi possível determinar o HOME de $DEPLOY_USER"

# ---- Preparar ~/.ssh e gerar chave ----
SSH_DIR="$DEPLOY_HOME/.ssh"
KEY_PATH="$SSH_DIR/$KEY_NAME"

install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_GROUP" "$SSH_DIR"

if [[ -f "$KEY_PATH" && -f "$KEY_PATH.pub" ]]; then
  log "Par de chaves já existe: $KEY_PATH"
else
  log "Gerando par de chaves SSH ed25519 em $KEY_PATH"
  sudo -u "$DEPLOY_USER" -H ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$KEY_PATH" -N ""
fi

# ---- Configurar ~/.ssh/config ----
SSH_CONFIG="$SSH_DIR/config"
if [[ -f "$SSH_CONFIG" ]] && grep -q "IdentityFile ~/.ssh/$KEY_NAME" "$SSH_CONFIG"; then
  log "Entrada SSH para github.com já configurada em $SSH_CONFIG"
else
  log "Escrevendo configuração SSH em $SSH_CONFIG"
  cat > "$SSH_CONFIG" <<EOF
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/$KEY_NAME
  IdentitiesOnly yes
EOF
  chown "$DEPLOY_USER:$DEPLOY_GROUP" "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"
fi

# ---- Ajustar permissões ~/.ssh ----
chmod 700 "$SSH_DIR"
chmod 600 "$KEY_PATH"
chmod 644 "$KEY_PATH.pub"
chown "$DEPLOY_USER:$DEPLOY_GROUP" "$KEY_PATH" "$KEY_PATH.pub"

log "Chave pública ($KEY_PATH.pub):"
echo "--------------------------------------------------------------------------------"
echo "AÇÃO NECESSÁRIA: Adicione a seguinte chave pública como uma 'Deploy Key' no seu repositório GitHub."
echo "Repositório: $REPO_SSH_URL"
echo "Navegue para: Settings > Deploy Keys > Add deploy key"
echo "   - Title: Camunda Deploy"
echo "   - Key:"
cat "$KEY_PATH.pub"
echo "   - NÃO marque 'Allow write access'."
echo "--------------------------------------------------------------------------------"

# ---- (Opcional) Clonar repositório ----
if [[ -n "$REPO_SSH_URL" ]]; then
  read -p "Pressione [Enter] para continuar após adicionar a chave ao GitHub..."

  PARENT_DIR=$(dirname "$TARGET_DIR")
  install -d -m 775 "$PARENT_DIR"
  chown "$DEPLOY_USER:$DEPLOY_GROUP" "$PARENT_DIR"

  if [[ -d "$TARGET_DIR/.git" ]]; then
    log "Repositório já presente em $TARGET_DIR; pulando clone."
  else
    log "Clonando repositório em $TARGET_DIR"
    # Aceita automaticamente a key de host do GitHub na primeira conexão
    if [[ -n "$GIT_BRANCH" ]]; then
      log "Clonando branch $GIT_BRANCH..."
      sudo -u "$DEPLOY_USER" -H env GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=accept-new' \
        git clone --branch "$GIT_BRANCH" "$REPO_SSH_URL" "$TARGET_DIR" || {
          warn "Falha ao clonar. Verifique se a Deploy Key foi adicionada e se a branch '$GIT_BRANCH' existe."
        }
    else
      log "Clonando branch padrão..."
      sudo -u "$DEPLOY_USER" -H env GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=accept-new' \
        git clone "$REPO_SSH_URL" "$TARGET_DIR" || {
          warn "Falha ao clonar. Verifique se a Deploy Key foi adicionada ao GitHub e tente novamente."
        }
    fi
  fi

  if [[ -d "$TARGET_DIR/.git" ]]; then
    log "Configurando identidade Git local em $TARGET_DIR"
    sudo -u "$DEPLOY_USER" -H git -C "$TARGET_DIR" config user.name "$GIT_NAME"
    sudo -u "$DEPLOY_USER" -H git -C "$TARGET_DIR" config user.email "$GIT_EMAIL"
  fi

  log "Ajustando permissões em $TARGET_DIR"
  chown -R "$DEPLOY_USER:$DEPLOY_GROUP" "$TARGET_DIR"
  chmod -R 775 "$TARGET_DIR"
  if command -v setfacl >/dev/null 2>&1; then
    setfacl -R -d -m g:"$DEPLOY_GROUP":rwx "$TARGET_DIR" || warn "setfacl (default) falhou"
    setfacl -R -m g:"$DEPLOY_GROUP":rwx "$TARGET_DIR" || warn "setfacl (apply) falhou"
  else
    warn "setfacl não encontrado; pulando configuração de ACLs padrão."
  fi
fi

# ---- Adicionar usuários ao grupo ----
if [[ ${#ADD_USERS[@]} -gt 0 ]]; then
  for u in "${ADD_USERS[@]}"; do
    if id -u "$u" >/dev/null 2>&1; then
      log "Adicionando usuário '$u' ao grupo '$DEPLOY_GROUP'"
      usermod -aG "$DEPLOY_GROUP" "$u"
    else
      warn "Usuário '$u' não existe; pulando."
    fi
  done
fi

log "Bootstrap concluído."
if [[ -n "$REPO_SSH_URL" ]]; then
  echo "Se o clone falhou, adicione a Deploy Key ao GitHub e reexecute com os mesmos parâmetros."
fi
