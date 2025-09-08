#!/usr/bin/env bash
# Verifica a saúde dos serviços do Camunda stack (dev/staging)

# Não usamos `set -e` para que todos os checks rodem mesmo com falhas
set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$REPO_DIR/dev/docker-compose.yaml"

# Detecta comando docker compose
if command -v docker compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "Erro: docker compose/docker-compose não encontrado. Instale Docker Compose."
  exit 1
fi

echo "Verificando saúde dos serviços..."
services=("zeebe" "elasticsearch" "operate" "tasklist" "identity")

# Tenta usar flags de v2; se falhar, faz fallback ao grep em `ps`
if "${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" ps --services --status running >/dev/null 2>&1; then
  running_services=$("${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" ps --services --status running)
  for service in "${services[@]}"; do
    if echo "$running_services" | grep -qx "$service"; then
      echo "✓ $service está rodando"
    else
      echo "✗ $service não está rodando"
    fi
  done
else
  # Fallback compatível com docker-compose v1
  ps_out=$("${COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" ps)
  for service in "${services[@]}"; do
    if echo "$ps_out" | grep -E "^$service[[:space:]]" | grep -Eq "Up|running|healthy"; then
      echo "✓ $service está rodando"
    else
      echo "✗ $service não está rodando"
    fi
  done
fi

echo
echo "Testando endpoints..."
curl -k -I https://dev.consultorunicoon.com.br/operate/actuator/health || true
curl -k -I https://dev.consultorunicoon.com.br/tasklist/actuator/health || true
curl -k -I https://dev.consultorunicoon.com.br/identity/actuator/health || true

echo
echo "Verificando índices Elasticsearch..."
curl -sS -X GET "http://localhost:9200/_cat/indices?v" || true

echo
echo "Verificando partições Zeebe..."
curl -sS -X GET "http://localhost:9600/actuator/health" || true

echo
echo "Checks concluídos."

