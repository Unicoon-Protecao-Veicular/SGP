#!/usr/bin/env bash
set -euo pipefail

# Exibe status dos certificados e permite forçar renovação.
# Renovação automática é gerenciada pelo cert-manager.
# Para forçar: bash production/scripts/renew-certificates.sh --force

FORCE="false"
if [[ "${1:-}" == "--force" ]]; then
  FORCE="true"
fi

echo "[cert-manager] Certificados atuais:"
kubectl get certificate -A || true

echo "[cert-manager] Desafios/ordens em andamento (se houver):"
kubectl get challenge,order -A || true

if [[ "$FORCE" == "true" ]]; then
  echo "[cert-manager] Tentando usar plugin 'kubectl cert-manager renew --all'..."
  if kubectl cert-manager renew --all 2>/dev/null; then
    echo "[cert-manager] Renovação solicitada via plugin."
    exit 0
  fi

  echo "[cert-manager] Plugin ausente. Forçando renovação anotando Certificates..."
  # Força uma renovação pontual adicionando a annotation de motivo de renovação
  # Disponível em versões recentes do cert-manager.
  mapfile -t CERTS < <(kubectl get certificate -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}')
  for entry in "${CERTS[@]}"; do
    ns=$(awk '{print $1}' <<<"$entry")
    name=$(awk '{print $2}' <<<"$entry")
    [[ -z "$ns" || -z "$name" ]] && continue
    echo " - Forçando $ns/$name"
    kubectl -n "$ns" patch certificate "$name" \
      --type=merge \
      -p '{"metadata":{"annotations":{"cert-manager.io/renewal-reason":"manual"}}}' || true
  done
  echo "[cert-manager] Sinalização de renovação enviada. Acompanhe com: kubectl describe certificate -n <ns> <name>"
fi

