#!/bin/bash
#
# Script para configurar o ambiente de desenvolvimento local para gerenciar o cluster de produção.
#
# Este script irá:
# 1. Solicitar o IP do servidor de produção e um e-mail para o Let's Encrypt.
# 2. Configurar o `kubectl` localmente, usando o `k3s.yaml` como template.
# 3. Gerar o manifest `cluster-issuers.yaml` para o cert-manager.
# 4. Gerar todos os segredos criptografados (Sealed Secrets) necessários.
# 5. Preparar um commit no Git com todos os arquivos gerados.
#

set -euo pipefail

# --- Funções de Log e Validação ---
log() { echo -e "\n\033[1;32m==> $1\033[0m"; }
info() { echo "    $1"; }
warn() { echo -e "\033[1;33m[AVISO] $1\033[0m"; }
die() { echo -e "\033[1;31m[ERRO] $1\033[0m" >&2; exit 1; }

# --- Verificação de Dependências ---
check_deps() {
    log "Verificando dependências..."
    local missing=0
    for cmd in git kubectl kubeseal envsubst; do
        if ! command -v "$cmd" &> /dev/null; then
            warn "Comando '$cmd' não encontrado. Por favor, instale-o."
            missing=1
        fi
done
    [[ "$missing" -eq 0 ]] && info "Todas as dependências foram encontradas."
    [[ "$missing" -eq 1 ]] && die "Dependências faltando. Abortando."
}

# --- Início do Script ---
check_deps

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Coleta de Dados do Usuário ---
log "Coletando informações necessárias"
read -p "  -> Digite o endereço de e-mail para o Let's Encrypt: " LE_EMAIL
[[ -z "$LE_EMAIL" ]] && die "O e-mail não pode ser vazio."

read -p "  -> Digite o endereço IP do servidor de produção: " SERVER_IP
[[ -z "$SERVER_IP" ]] && die "O IP do servidor não pode ser vazio."

# --- Configuração do Kubeconfig ---
log "Configurando o acesso ao cluster com kubectl"
K3S_TEMPLATE_PATH="$ROOT_DIR/k3s.yaml"
KUBECONFIG_PATH="$HOME/.kube/config"

[[ ! -f "$K3S_TEMPLATE_PATH" ]] && die "Arquivo template 'k3s.yaml' não encontrado na raiz do projeto."

info "Substituindo o IP no template do k3s.yaml..."
# Substitui o IP placeholder (127.0.0.1) pelo IP fornecido
K3S_CONFIG_CONTENT=$(sed "s/127.0.0.1/$SERVER_IP/" "$K3S_TEMPLATE_PATH")

mkdir -p "$(dirname "$KUBECONFIG_PATH")"
if [[ -f "$KUBECONFIG_PATH" ]]; then
    mv "$KUBECONFIG_PATH" "${KUBECONFIG_PATH}.bak-$(date +%s)"
    info "Backup do seu kubeconfig existente foi criado em ${KUBECONFIG_PATH}.bak-மையில்..."
fi

echo "$K3S_CONFIG_CONTENT" > "$KUBECONFIG_PATH"
info "Seu '$KUBECONFIG_PATH' foi configurado para acessar o servidor $SERVER_IP."
info "Testando a conexão com o cluster..."
if kubectl get nodes &> /dev/null; then
    info "Conexão com o cluster bem-sucedida!"
else
    warn "Não foi possível conectar ao cluster. Verifique o IP e a conectividade de rede."
fi

# --- Geração dos Manifests ---
log "Gerando manifests de configuração"

# 1. ClusterIssuers
ISSUER_TEMPLATE="$ROOT_DIR/production/k8s/cert-manager/cluster-issuers.yaml.tpl"
ISSUER_OUTPUT="$ROOT_DIR/production/k8s/cert-manager/cluster-issuers.yaml"
info "Gerando '$ISSUER_OUTPUT' com o e-mail $LE_EMAIL..."
export LE_EMAIL
envsubst < "$ISSUER_TEMPLATE" > "$ISSUER_OUTPUT"

# 2. Segredos
log "Gerando segredos criptografados (Sealed Secrets)"
info "Isso pode demorar um pouco, pois depende da comunicação com o cluster..."
bash "$SCRIPT_DIR/create-all-secrets.sh"

# --- Preparação do Commit ---
log "Preparando commit no Git"
CAMUNDA_SECRET_PATH="$ROOT_DIR/production/k8s/secrets/sealed-camunda-credentials.yaml"
GRAFANA_SECRET_PATH="$ROOT_DIR/production/k8s/secrets/sealed-grafana-credentials.yaml"

info "Adicionando arquivos gerados ao Git..."
git add "$ISSUER_OUTPUT"
git add "$CAMUNDA_SECRET_PATH"
git add "$GRAFANA_SECRET_PATH"

COMMIT_MSG="feat: Configure local environment and generate secrets

- Configura os ClusterIssuers para Let's Encrypt.
- Gera e criptografa os segredos para Camunda e Grafana."

info "Criando commit..."
git commit -m "$COMMIT_MSG"

# --- Finalização ---
log "Processo concluído com sucesso!"
echo
info "Um commit foi criado com todos os arquivos de configuração necessários."
info "Para finalizar, execute o seguinte comando para enviar as mudanças para o repositório:"
echo
echo -e "  \033[1;34mgit push\033[0m"
echo
