#!/bin/bash

CAMUNDA_DIR="/srv/camunda"

# Detect Container Engine and Compose command
# Order of preference:
# 1) docker compose   2) docker-compose   3) podman compose   4) podman-compose
ENGINE_CMD=""
COMPOSE_CMD=""

# Helper: run compose with sudo fallback on permission denied
run_compose() {
    local err
    err=$(mktemp /tmp/compose_err.XXXXXX)
    if $COMPOSE_CMD "$@" 2>"$err"; then
        rm -f "$err"
        return 0
    fi
    if grep -qi "permission denied" "$err"; then
        echo "Permissão negada ao acessar o socket do container runtime. Tentando com sudo..."
        if sudo $COMPOSE_CMD "$@"; then
            rm -f "$err"
            return 0
        fi
    fi
    echo "Falha ao executar '$COMPOSE_CMD $*'" >&2
    cat "$err" >&2
    rm -f "$err"
    return 1
}

# Helper: run engine (e.g., docker/podman) with sudo fallback for read-only commands
run_engine() {
    local err
    err=$(mktemp /tmp/engine_err.XXXXXX)
    if $ENGINE_CMD "$@" 2>"$err"; then
        rm -f "$err"
        return 0
    fi
    if grep -qi "permission denied" "$err"; then
        echo "Permissão negada ao acessar o socket do container runtime. Tentando com sudo..."
        if sudo $ENGINE_CMD "$@"; then
            rm -f "$err"
            return 0
        fi
    fi
    echo "Falha ao executar '$ENGINE_CMD $*'" >&2
    cat "$err" >&2
    rm -f "$err"
    return 1
}

if command -v docker >/dev/null 2>&1; then
    if docker compose version >/dev/null 2>&1; then
        ENGINE_CMD="docker"
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        ENGINE_CMD="docker"
        COMPOSE_CMD="docker-compose"
    fi
fi

if [ -z "$COMPOSE_CMD" ] && command -v podman >/dev/null 2>&1; then
    if podman compose version >/dev/null 2>&1; then
        ENGINE_CMD="podman"
        COMPOSE_CMD="podman compose"
    elif command -v podman-compose >/dev/null 2>&1; then
        ENGINE_CMD="podman"
        COMPOSE_CMD="podman-compose"
    fi
fi

if [ -z "$COMPOSE_CMD" ] || [ -z "$ENGINE_CMD" ]; then
    echo "Erro: Nenhum engine/compose suportado encontrado."
    echo "Tente instalar um dos seguintes:"
    echo "- Docker (com 'docker compose' ou 'docker-compose')"
    echo "- Podman (com 'podman compose' ou 'podman-compose')"
    exit 127
fi

case "$1" in
    start)
        echo "Iniciando ambiente DEV..."
        cd "$CAMUNDA_DIR/dev"
        run_compose up -d || exit 1
        
        echo "Iniciando ambiente STAGING..."
        cd "$CAMUNDA_DIR/staging"
        run_compose up -d || exit 1
        
        echo "Ambientes iniciados (Camunda 8):"
        HOST_IP=$(hostname -I | awk '{print $1}')
        echo "DEV - Operate:   http://$HOST_IP:8081"
        echo "DEV - Tasklist:  http://$HOST_IP:8082"
        echo "DEV - Identity:  http://$HOST_IP:8084"
        echo "DEV - Keycloak:  http://$HOST_IP:18080"
        echo "STAGING - Operate:   http://$HOST_IP:8181"
        echo "STAGING - Tasklist:  http://$HOST_IP:8182"
        echo "STAGING - Identity:  http://$HOST_IP:8184"
        echo "STAGING - Keycloak:  http://$HOST_IP:28080"
        ;;
    stop)
        echo "Parando ambiente DEV..."
        cd "$CAMUNDA_DIR/dev"
        run_compose down || exit 1
        
        echo "Parando ambiente STAGING..."
        cd "$CAMUNDA_DIR/staging"
        run_compose down || exit 1
        ;;
    restart)
        $0 stop
        sleep 5
        $0 start
        ;;
    status)
        echo "Containers em execução:"
        run_engine ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|status|backup}"
        exit 1
        ;;
esac