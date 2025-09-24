#!/usr/bin/env bash
set -euo pipefail

VERSION="v2.12.1" # Use a versão estável mais recente ou a desejada

log() {
  echo "==> [Argo CD CLI Install] $*"
}

if command -v argocd &> /dev/null; then
    log "Argo CD CLI já está instalada. Versão: $(argocd version --client --short)"
    exit 0
fi

log "Instalando a CLI do Argo CD versão ${VERSION}..."

curl -sSL -o /usr/local/bin/argocd "https://github.com/argoproj/argo-cd/releases/download/${VERSION}/argocd-linux-amd64"

chmod +x /usr/local/bin/argocd

log "CLI do Argo CD instalada com sucesso."
log "Versão: $(argocd version --client --short)"