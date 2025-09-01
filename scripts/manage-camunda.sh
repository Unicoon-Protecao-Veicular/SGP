#!/bin/bash

CAMUNDA_DIR="/srv/camunda"

# Detect Container Engine and Compose command
# Order of preference:
# 1) docker compose   2) docker-compose   3) podman compose   4) podman-compose
ENGINE_CMD=""
COMPOSE_CMD=""

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
        $COMPOSE_CMD up -d
        
        echo "Iniciando ambiente STAGING..."
        cd "$CAMUNDA_DIR/staging"
        $COMPOSE_CMD up -d
        
        echo "Ambientes iniciados:"
        echo "DEV: http://$(hostname -I | awk '{print $1}'):8080/camunda"
        echo "STAGING: http://$(hostname -I | awk '{print $1}'):8081/camunda"
        ;;
    stop)
        echo "Parando ambiente DEV..."
        cd "$CAMUNDA_DIR/dev"
        $COMPOSE_CMD down
        
        echo "Parando ambiente STAGING..."
        cd "$CAMUNDA_DIR/staging"
        $COMPOSE_CMD down
        ;;
    restart)
        $0 stop
        sleep 5
        $0 start
        ;;
    status)
        echo "Containers em execução:"
        $ENGINE_CMD ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|status|backup}"
        exit 1
        ;;
esac