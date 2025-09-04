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

## Bootstrap do Usuário Camunda-Deploy
Este script prepara um servidor Ubuntu para gerenciar os ambientes Camunda. Ele cria um usuário dedicado (`camunda-deploy`), gera chaves SSH, instala as dependências necessárias (`git`, `acl`, etc.) e, opcionalmente, clona o repositório de configuração.

**Execução (como root):**
```bash
# Exemplo para criar o usuário e clonar o repositório
sudo bash scripts/bootstrap-camunda-deploy.sh --repo git@github.com:seu-usuario/camunda-config.git

# Exemplo para adicionar outros usuários ao grupo de deploy
sudo bash scripts/bootstrap-camunda-deploy.sh --add-user usuario1 --add-user usuario2
```
O script imprimirá a chave pública do usuário `camunda-deploy`. Adicione-a como uma **Deploy Key** (com permissão de leitura) no repositório do GitHub para permitir o clone. Se o clone falhar na primeira execução, adicione a chave e execute o script novamente.

## Próximos passos (ambientes dev/staging)

- Após clonar o repositório, execute `scripts/config-camunda.sh` para configurar o Camunda (ex.: `bash scripts/config-camunda.sh`).
- Definir variáveis em `dev/.env` e `staging/.env` (não commitar segredos reais).
