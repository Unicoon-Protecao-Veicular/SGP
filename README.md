# SGP — Estrutura do Projeto

Estrutura padronizada para ambientes e código-fonte do Camunda (microserviços, workflows, regras de decisão).

## Pastas

- `dev/`: Arquivos de configuração do ambiente de desenvolvimento (Docker Compose).
- `staging/`: Arquivos de configuração do ambiente de staging (Docker Compose).
- `production/`: Arquivos de configuração/manifests para produção (Kubernetes/Helm).
  - `k8s/`: Manifests do Kubernetes.
  - `helm/`: Charts Helm (opcional).
- `src/`: Código-fonte do projeto
  - `microservice-a/`: Exemplo de microserviço.
  - `bpmn/`: Workflows BPMN.
  - `dmn/`: Regras DMN.

## Próximos passos

- Após clonar o repositório, execute `scripts/config-camunda.sh` para configurar o Camunda (ex.: `bash scripts/config-camunda.sh`).
- Definir variáveis em `dev/.env` e `staging/.env` (não commitar segredos reais).
