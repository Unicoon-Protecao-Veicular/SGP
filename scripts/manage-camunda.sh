#!/bin/bash

CAMUNDA_DIR="/srv/camunda"

case "$1" in
    start)
        echo "Iniciando ambiente DEV..."
        cd $CAMUNDA_DIR/dev
        podman-compose up -d
        
        echo "Iniciando ambiente STAGING..."
        cd $CAMUNDA_DIR/staging
        podman-compose up -d
        
        echo "Ambientes iniciados:"
        echo "DEV: http://$(hostname -I | awk '{print $1}'):8080/camunda"
        echo "STAGING: http://$(hostname -I | awk '{print $1}'):8081/camunda"
        ;;
    stop)
        echo "Parando ambiente DEV..."
        cd $CAMUNDA_DIR/dev
        podman-compose down
        
        echo "Parando ambiente STAGING..."
        cd $CAMUNDA_DIR/staging
        podman-compose down
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
    backup)
        echo "Criando backup dos ambientes..."
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        
        # Backup do ambiente DEV
        cd $CAMUNDA_DIR/dev
        podman-compose exec camunda-dev tar czf /tmp/camunda-dev-backup-$TIMESTAMP.tar.gz /camunda/database
        podman cp camunda-dev:/tmp/camunda-dev-backup-$TIMESTAMP.tar.gz $CAMUNDA_DIR/dev/backups/
        
        # Backup do ambiente STAGING
        cd $CAMUNDA_DIR/staging
        podman-compose exec postgres-staging pg_dump -U camunda camunda > $CAMUNDA_DIR/staging/backups/camunda-staging-backup-$TIMESTAMP.sql
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|status|backup}"
        exit 1
        ;;
esac