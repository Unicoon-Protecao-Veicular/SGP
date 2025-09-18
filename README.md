# SGP - Sistema de Gestão de Processos com Camunda 8

Este repositório contém a infraestrutura como código (IaC) para a implantação do Sistema de Gestão de Processos, baseado na plataforma Camunda 8.

A implantação é totalmente automatizada e gerenciada via GitOps.

## Ambientes

- **Produção**: A configuração completa para o ambiente de produção, incluindo scripts de bootstrap, manifestos Kubernetes e configuração de aplicações ArgoCD.

## Implantação em Produção

Para instruções detalhadas sobre como implantar o ambiente de produção do zero, consulte o guia no diretório de produção:

**[>> Guia de Implantação em Produção](./production/README.md)**

## Próximos passos (ambientes dev/staging)

- Execute a configuração apenas para `dev` ou `staging`:
  - `bash scripts/config-camunda.sh dev`
  - `bash scripts/config-camunda.sh staging`
- O script valida o ambiente e recusa qualquer valor diferente de `dev` ou `staging`.
- Definir variáveis em `dev/.env` e `staging/.env` (não commitar segredos reais).

