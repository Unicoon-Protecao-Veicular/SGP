#!/bin/bash

CAMUNDA_DIR="/srv/camunda"

# Detect Container Engine and Compose command
# Order of preference:
# 1) docker compose   2) docker-compose   3) podman compose   4) podman-compose
ENGINE_CMD=()
COMPOSE_CMD=()

# Helper: run compose with sudo fallback on permission denied
run_compose() {
    local err
    err=$(mktemp /tmp/compose_err.XXXXXX)
    if "${SUDO_PREFIX[@]}" "${COMPOSE_CMD[@]}" "$@" 2>"$err"; then
        rm -f "$err"
        return 0
    fi
    # Se por algum motivo o estado do socket mudou, tenta com sudo “forçado”
    if ! printf '' >/dev/null 2>&1; then :; fi
    if grep -qi "permission denied" "$err"; then
        echo "Permissão negada ao acessar o socket. Tentando com sudo..."
        if sudo -E "${COMPOSE_CMD[@]}" "$@"; then
            rm -f "$err"
            return 0
        fi
    fi
    echo "Falha ao executar '${COMPOSE_CMD[*]} $*'" >&2
    cat "$err" >&2
    rm -f "$err"
    return 1
}

# Helper: run engine (e.g., docker/podman) with sudo fallback for read-only commands
run_engine() {
    local err
    err=$(mktemp /tmp/engine_err.XXXXXX)
    if "${SUDO_PREFIX[@]}" "${ENGINE_CMD[@]}" "$@" 2>"$err"; then
        rm -f "$err"
        return 0
    fi
    if grep -qi "permission denied" "$err"; then
        echo "Permissão negada ao acessar o socket. Tentando com sudo..."
        if sudo -E "${ENGINE_CMD[@]}" "$@"; then
            rm -f "$err"
            return 0
        fi
    fi
    echo "Falha ao executar '${ENGINE_CMD[*]} $*'" >&2
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

if [ ${#COMPOSE_CMD[@]} -eq 0 ] && command -v podman >/dev/null 2>&1; then
    if podman compose version >/dev/null 2>&1; then
        ENGINE_CMD="podman"
        COMPOSE_CMD="podman compose"
    elif command -v podman-compose >/dev/null 2>&1; then
        ENGINE_CMD="podman"
        COMPOSE_CMD="podman-compose"
    fi
fi

if [ ${#COMPOSE_CMD[@]} -eq 0 ] || [ ${#ENGINE_CMD[@]} -eq 0 ]; then
    echo "Erro: Nenhum engine/compose suportado encontrado."
    echo "Tente instalar um dos seguintes:"
    echo "- Docker (com 'docker compose' ou 'docker-compose')"
    echo "- Podman (com 'podman compose' ou 'podman-compose')"
    exit 127
fi

SUDO_PREFIX=()

if ! "${ENGINE_CMD[@]}" info >/dev/null 2>&1; then
    SUDO_PREFIX=(sudo -E)
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
            echo "DEV - Operate:     https://$HOST_IP/operate"
            echo "DEV - Tasklist:    https://$HOST_IP/tasklist"
            echo "DEV - Identity:    https://$HOST_IP/identity"
            echo "DEV - Keycloak:    https://$HOST_IP/keycloak"
            echo "DEV - Web Modeler: https://$HOST_IP/modeler"
            ;;
        staging)
            echo "STAGING - Operate:   http://$HOST_IP:8181"
            echo "STAGING - Tasklist:  http://$HOST_IP:8182"
            echo "STAGING - Identity:  http://$HOST_IP:8184"
            echo "STAGING - Keycloak:  http://$HOST_IP:28080"
            ;;
    esac
}

# Start a specific environment with a more robust staggered startup
start_env() {
    local env="$1"
    local dir
    dir=$(resolve_env_dir "$env") || { echo "Ambiente inválido: $env"; return 2; }
    echo "Iniciando ambiente $env com inicialização orquestrada (versão robusta)..."
    cd "$dir" || return 1

    local PROJECT_NAME
    PROJECT_NAME=$(basename "$dir")   # ex.: dev ou staging
    local SLEEP_INTERVAL=30 # 30 segundos deve ser um bom equilíbrio aqui

    # -- ETAPA 1: Bancos de dados e Elasticsearch --
    echo "--- Etapa 1/5: Iniciando bancos de dados e Elasticsearch..."
    run_compose -p "$PROJECT_NAME" --env-file .env up -d postgres web-modeler-db elasticsearch || return 1
    echo "Aguardando $SLEEP_INTERVAL segundos..."
    sleep $SLEEP_INTERVAL

    # -- ETAPA 2: Keycloak e serviços de suporte --
    echo "--- Etapa 2/5: Iniciando Keycloak e serviços de suporte..."
    run_compose -p "$PROJECT_NAME" --env-file .env up -d keycloak mailpit web-modeler-websockets || return 1
    echo "Aguardando $SLEEP_INTERVAL segundos para o Keycloak inicializar completamente..."
    sleep $SLEEP_INTERVAL

    # -- ETAPA 3: Identity (Crítico) --
    echo "--- Etapa 3/5: Iniciando o Identity para configurar o Keycloak..."
    run_compose -p "$PROJECT_NAME" --env-file .env up -d identity || return 1
    echo "Aguardando $SLEEP_INTERVAL segundos para o Identity (e a configuração do Keycloak) estabilizar..."
    sleep $SLEEP_INTERVAL

    # -- ETAPA 4: Core do Camunda (Zeebe, Operate, Tasklist, Connectors) --
    echo "--- Etapa 4/5: Iniciando o core do Camunda..."
    run_compose -p "$PROJECT_NAME" --env-file .env up -d zeebe operate tasklist connectors || return 1
    echo "Aguardando $SLEEP_INTERVAL segundos para os componentes principais se conectarem..."
    sleep $SLEEP_INTERVAL

    # -- ETAPA 5: Web Modeler --
    echo "--- Etapa 5/5: Iniciando os serviços do Web Modeler..."
    run_compose -p "$PROJECT_NAME" --env-file .env up -d web-modeler-restapi web-modeler-webapp nginx || return 1

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
    cd "$dir" || return 1
    run_compose -p "$PROJECT_NAME" down || return 1
    echo "Ambiente $env parado."
}

# Clean a specific environment (stops and removes containers, volumes, and networks)
clean_env() {
    local env="$1"
    local dir
    dir=$(resolve_env_dir "$env") || { echo "Ambiente inválido: $env"; return 2; }
    echo "Limpando completamente o ambiente $env (contêineres, volumes e redes)..."
    cd "$dir" || return 1
    # --remove-orphans is crucial for cleaning up old service names
    # -v removes named volumes
    run_compose down --remove-orphans -v || return 1
    echo "Limpeza do ambiente $env concluída."
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
    clean)
        [ -z "$2" ] && { echo "Uso: $0 clean {dev|staging}"; exit 2; }
        clean_env "$2" || exit 1
        ;;
    status)
        echo "Containers em execução:"
        run_engine ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|clean} {dev|staging}"
        echo "       $0 status"
        exit 1
        ;;
esac