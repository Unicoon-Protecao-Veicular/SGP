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
- Pré-requisito: cria e configura o usuário `camunda-deploy` na VPS com chave SSH, permissões e (opcional) clona o repositório para `/srv/camunda`.
- Pré-instalação: `git`, `openssh-client`, e (opcional) `acl` para aplicar ACLs padrão:
    `sudo apt update && sudo apt install -y git openssh-client && sudo apt install -y acl`
- Execução (como root):
  - Gerar usuário/chave e clonar o repo:
    - `sudo bash scripts/bootstrap-camunda-deploy.sh --repo git@github.com:seu-usuario/camunda-config.git`
  - Adicionar outros usuários ao grupo de deploy:
    - `sudo bash scripts/bootstrap-camunda-deploy.sh --add-user usuario1 --add-user usuario2`
- O script imprime a chave pública do `camunda-deploy` (ex.: `~/.ssh/camunda-deploy.pub`). Adicione-a como Deploy Key (read) no GitHub do repositório alvo. Se o clone falhar por falta de permissão, adicione a chave e reexecute o script.
- Após o bootstrap, utilize `scripts/config-camunda.sh {dev|staging}` e `scripts/update-camunda.sh` normalmente.

## Próximos passos (ambientes dev/staging)

- Após clonar o repositório, execute `scripts/config-camunda.sh` para configurar o Camunda (ex.: `bash scripts/config-camunda.sh`).
- Definir variáveis em `dev/.env` e `staging/.env` (não commitar segredos reais).
