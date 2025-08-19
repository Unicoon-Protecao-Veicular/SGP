# Ambiente de Produção

Este diretório contém os artefatos de implantação para produção.

## Estrutura

- `k8s/`: Manifests do Kubernetes (Deployments, Services, Ingress, ConfigMaps, Secrets templates).
- `helm/`: (Opcional) Charts Helm para facilitar a implantação e versionamento.

## Como usar

1. Ajuste os manifests em `production/k8s/` conforme o cluster.
2. Caso use Helm, mantenha os charts em `production/helm/` e publique versões conforme o ciclo de releases.
3. Defina variáveis sensíveis via Secret do Kubernetes (não commitar valores reais).

## Observações

- Este repositório não deve conter segredos reais.
- Recomenda-se usar pipelines (CI/CD) para aplicar as mudanças.
