#!/bin/bash

CAMUNDA_DIR="/srv/camunda"

# Detect Podman Compose command: prefer 'podman compose' then fallback to 'podman-compose'
if podman compose version >/dev/null 2>&1; then
    COMPOSE_CMD="podman compose"
elif command -v podman-compose >/dev/null 2>&1; then
    COMPOSE_CMD="podman-compose"
else
    echo "Erro: Nem 'podman compose' nem 'podman-compose' foram encontrados no sistema."
    echo "Instale o Podman com suporte a 'compose' (recomendado) ou o pacote 'podman-compose'."
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
        podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|status|backup}"
        exit 1
        ;;
esac