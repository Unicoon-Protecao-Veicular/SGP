#!/bin/bash

# Script para configurar firewall
sudo ufw allow 8080/tcp comment 'Camunda DEV'
sudo ufw allow 8081/tcp comment 'Camunda STAGING'
sudo ufw reload
sudo ufw status verbose