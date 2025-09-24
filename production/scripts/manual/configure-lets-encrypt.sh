#!/usr/bin/env bash
set -euo pipefail

# Cria/atualiza os ClusterIssuers do Let's Encrypt (staging e prod)
# Uso: LE_EMAIL=seu@email.com bash production/scripts/configure-lets-encrypt.sh

if [[ -z "${LE_EMAIL:-}" ]]; then
  echo "Erro: defina a variável LE_EMAIL com seu e-mail de contato do Let's Encrypt."
  echo "Ex.: LE_EMAIL=admin@seu-dominio.com bash production/scripts/configure-lets-encrypt.sh"
  exit 1
fi

command -v envsubst >/dev/null 2>&1 || {
  echo "Erro: 'envsubst' não encontrado. Instale o pacote gettext-base (Debian/Ubuntu) ou gettext." >&2
  exit 1
}

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../.." && pwd)
TPL="$ROOT/production/k8s/cert-manager/cluster-issuers.yaml.tpl"

if [[ ! -f "$TPL" ]]; then
  echo "Template não encontrado: $TPL" >&2
  exit 1
fi

echo "[Let's Encrypt] Gerando manifests de ClusterIssuer com LE_EMAIL=$LE_EMAIL ..."
export LE_EMAIL
envsubst < "$TPL" | kubectl apply -f -

echo "[Let's Encrypt] Verificando recursos:"
kubectl get clusterissuer

echo "[Let's Encrypt] Pronto. Atualize/aplique seus Ingresses com a annotation cert-manager.io/cluster-issuer=letsencrypt-prod."

