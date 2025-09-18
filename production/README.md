# Ambiente de Produção SGP

Este diretório contém toda a configuração e scripts para implantar o ambiente de produção do SGP (Sistema de Gestão de Processos) em um cluster Kubernetes.

## Pré-requisitos

### Servidor de Produção
- Servidor Linux (Ubuntu, etc.) com acesso root.
- Docker instalado.

### Máquina Local (do Desenvolvedor)
- **`kubectl`**: Instalado e configurado para acessar seu cluster Kubernetes.
- **`kubeseal`**: A ferramenta de linha de comando para criptografar os segredos. A instalação varia por sistema operacional.
  - **macOS (usando Homebrew):** `brew install kubeseal`
  - **Linux/Windows:** Baixe o binário da [página de releases do Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets/releases) e adicione ao seu PATH.

## Fluxo de Implantação (Bootstrap)

Para implantar o ambiente do zero em um novo servidor, siga os passos:

1.  **Preparar o Servidor**: Clone este repositório em um servidor Linux com Docker instalado.

2.  **Executar o Setup Principal**: O script principal orquestra a instalação de todas as dependências de infraestrutura.
    ```bash
    bash production/scripts/setup-production.sh
    ```
    Este script irá instalar: K3s, Helm, ArgoCD e o controller do Sealed Secrets.

3.  **Gerar o Segredo do Banco de Dados**: As senhas do banco de dados não são armazenadas no Git. Você precisa gerá-las e criptografá-las usando o script que preparamos.
    ```bash
    # Dê permissão de execução primeiro
    chmod +x production/scripts/create-sealed-secret.sh

    # Execute o script e siga as instruções
    ./production/scripts/create-sealed-secret.sh
    ```
    - Para instruções detalhadas sobre este passo, consulte o [Guia de Criação de Segredos](./k8s/secrets/README.md).
    - Após a execução, faça o commit do arquivo `sealed-postgresql-credentials.yaml` que será gerado.

4.  **Implantar as Aplicações via ArgoCD**: O último script instrui o ArgoCD a instalar as aplicações definidas no repositório (Camunda e os Segredos).
    ```bash
    bash production/scripts/bootstrap-apps.sh
    ```

Após estes passos, o ArgoCD irá sincronizar o estado do repositório com o cluster, e o ambiente completo do Camunda estará no ar.