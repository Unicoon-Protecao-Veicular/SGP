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

# Resolve environment directory from name
resolve_env_dir() {
    case "$1" in
        dev) echo "$CAMUNDA_DIR/dev" ;;
        staging) echo "$CAMUNDA_DIR/staging" ;;
        *) return 1 ;;
    esac
}

# Print service URLs by environment
print_urls() {
    local env="$1"
    local HOST_IP
    HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$HOST_IP" ] && HOST_IP="localhost"

    case "$env" in
        dev)
            echo "DEV - Operate:   http://$HOST_IP:8081"
            echo "DEV - Tasklist:  http://$HOST_IP:8082"
            echo "DEV - Identity:  http://$HOST_IP:8084"
            echo "DEV - Keycloak:  http://$HOST_IP:18080"
            ;;
        staging)
            echo "STAGING - Operate:   http://$HOST_IP:8181"
            echo "STAGING - Tasklist:  http://$HOST_IP:8182"
            echo "STAGING - Identity:  http://$HOST_IP:8184"
            echo "STAGING - Keycloak:  http://$HOST_IP:28080"
            ;;
    esac
}

# Start a specific environment with staggered service startup
start_env() {
    local env="$1"
    local dir
    dir=$(resolve_env_dir "$env") || { echo "Ambiente inválido: $env"; return 2; }
    echo "Iniciando ambiente $env com inicialização orquestrada..."
    cd "$dir" || return 1

    # Define o tempo de espera em segundos entre os grupos de serviços.
    # Se ainda encontrar erros, você pode aumentar este valor para 30 ou 45.
    local SLEEP_INTERVAL=20

    # -- ETAPA 1: Iniciar bancos de dados e serviços base --
    echo "--- Etapa 1/4: Iniciando bancos de dados, Elasticsearch, Keycloak e serviços de suporte..."
    # CORREÇÃO APLICADA AQUI: 'postgres-identity' foi substituído por 'postgres-keycloak'
    run_compose up -d postgres-keycloak postgres-modeler elasticsearch keycloak mailhog modeler-websockets || return 1
    echo "Aguardando $SLEEP_INTERVAL segundos para a estabilização dos serviços base..."
    sleep $SLEEP_INTERVAL

    # -- ETAPA 2: Iniciar o motor Zeebe e os Conectores --
    echo "--- Etapa 2/4: Iniciando o motor Zeebe e os Connectors..."
    run_compose up -d zeebe connectors || return 1
    echo "Aguardando $SLEEP_INTERVAL segundos para a estabilização do Zeebe..."
    sleep $SLEEP_INTERVAL

    # -- ETAPA 3: Iniciar os aplicativos principais do Camunda (Identity, Operate, Tasklist) --
    echo "--- Etapa 3/4: Iniciando Identity, Operate e Tasklist..."
    run_compose up -d identity operate tasklist || return 1
    echo "Aguardando $SLEEP_INTERVAL segundos para a estabilização dos aplicativos principais..."
    sleep $SLEEP_INTERVAL

    # -- ETAPA 4: Iniciar os componentes do Web Modeler --
    echo "--- Etapa 4/4: Iniciando os serviços do Web Modeler..."
    run_compose up -d modeler-restapi modeler-webapp || return 1

    echo ""
    echo "Ambiente $env iniciado com sucesso!"
    print_urls "$env"
}

# Stop a specific environment
stop_env() {
    local env="$1"
    local dir
    dir=$(resolve_env_dir "$env") || { echo "Ambiente inválido: $env"; return 2; }
    echo "Parando ambiente $env..."
    cd "$dir"
    run_compose down || return 1
}

case "$1" in
    start)
        [ -z "$2" ] && { echo "Uso: $0 start {dev|staging}"; exit 2; }
        start_env "$2" || exit 1
        ;;
    stop)
        [ -z "$2" ] && { echo "Uso: $0 stop {dev|staging}"; exit 2; }
        stop_env "$2" || exit 1
        ;;
    restart)
        [ -z "$2" ] && { echo "Uso: $0 restart {dev|staging}"; exit 2; }
        stop_env "$2" || exit 1
        sleep 2
        start_env "$2" || exit 1
        ;;
    status)
        echo "Containers em execução:"
        run_engine ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        ;;
    *)
        echo "Uso: $0 {start|stop|restart} {dev|staging} | status"
        exit 1
        ;;
esac