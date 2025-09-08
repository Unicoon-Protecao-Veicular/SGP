#!/bin/bash

# Script para configurar firewall (UFW) para Camunda via Nginx
# Publicamos apenas HTTP/HTTPS (80/443) e mantemos portas internas fechadas.

set -euo pipefail

echo "[UFW] Liberando portas HTTP/HTTPS públicas..."
sudo ufw allow 80/tcp comment 'Camunda - HTTP (Nginx)'
sudo ufw allow 443/tcp comment 'Camunda - HTTPS (Nginx)'

# As portas internas abaixo NÃO serão abertas ao público por segurança,
# pois o acesso externo deve ocorrer somente via Nginx (80/443).
# Mantidas aqui apenas como referência e comentadas:
# sudo ufw allow 8081/tcp comment 'Camunda DEV - Operate'
# sudo ufw allow 8082/tcp comment 'Camunda DEV - Tasklist'
# sudo ufw allow 8084/tcp comment 'Camunda DEV - Identity'
# sudo ufw allow 18080/tcp comment 'Camunda DEV - Keycloak'
# sudo ufw allow 8181/tcp comment 'Camunda STAGING - Operate'
# sudo ufw allow 8182/tcp comment 'Camunda STAGING - Tasklist'
# sudo ufw allow 8184/tcp comment 'Camunda STAGING - Identity'
# sudo ufw allow 28080/tcp comment 'Camunda STAGING - Keycloak'

# Opcional: libere gRPC do Zeebe se precisar acessar externamente
# sudo ufw allow 26500/tcp comment 'Camunda DEV - Zeebe gRPC'
# sudo ufw allow 26510/tcp comment 'Camunda STAGING - Zeebe gRPC'

echo "[UFW] Recarregando regras..."
sudo ufw reload

echo "[UFW] Status:"
sudo ufw status numbered
sudo ufw status verbose
