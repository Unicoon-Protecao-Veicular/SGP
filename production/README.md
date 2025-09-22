# Ambiente de Produção SGP

Este diretório contém toda a configuração para implantar o ambiente de produção do SGP (Sistema de Gestão de Processos) em um cluster Kubernetes, utilizando uma abordagem GitOps com ArgoCD.

## Visão Geral da Arquitetura

A implantação é gerenciada pelo **ArgoCD**, que utiliza o repositório Git como fonte da verdade. Isso significa que todas as configurações do cluster, incluindo aplicações e infraestrutura, são declaradas como código. As alterações no cluster são feitas através de commits no Git, garantindo um processo rastreável e automatizado.

Para gerenciar dependências entre os serviços (como garantir que o `cert-manager` esteja pronto antes de criar `Ingresses` com TLS), usamos as **Sync Waves** do ArgoCD, que orquestram a ordem de implantação.

## Pré-requisitos

Antes de começar, garanta que os seguintes requisitos sejam atendidos.

### Servidor de Produção
- Um servidor Linux (ex: Ubuntu 20.04+) com acesso root/sudo.
- `git` instalado.
- Docker instalado.

### Máquina Local (do Engenheiro de Implantação)
- `git` instalado para clonar o repositório.
- `kubectl` para interagir com o cluster.
- `kubeseal` para criptografar segredos.
- `envsubst` (geralmente parte do pacote `gettext`) para substituir variáveis em templates.

## Fluxo de Implantação do Zero

O processo de implantação é dividido em três fases principais.

---

### Fase 1: Setup do Servidor de Produção

**Objetivo:** Preparar o servidor com a infraestrutura base do Kubernetes.
**Onde executar:** No terminal do seu **servidor de produção**.

1.  **Execute o boostrap do camunda deploy**
    ```bash
        scp bootstrap-camunda-deploy.sh root@<IP SERVIDOR>:~
        bash bootstrap-camunda-deploy.sh --repo <SSH repositório GIT> --branch <BRANCH EM USO>
    ```

2.  **Execute o Script de Setup da Infraestrutura**

    Este é o script principal que instala todos os componentes de base no servidor.

    ```bash
    bash production/scripts/setup-production.sh
    ```

    O que este script faz:
    - Instala o **K3s** (uma distribuição leve de Kubernetes).
    - Instala o **Helm** (gerenciador de pacotes para Kubernetes).
    - Instala o **ArgoCD** (ferramenta de GitOps para deployment contínuo).
    - Instala o controller do **Sealed Secrets** (para gerenciar segredos de forma segura no Git).
    - Configura o ArgoCD para ter acesso a este repositório Git via SSH.

Ao final desta fase, você terá um cluster Kubernetes funcional com o ArgoCD pronto para implantar as aplicações.

---

### Fase 2: Configuração do Ambiente Local e Geração de Segredos

**Objetivo:** Configurar sua máquina local para se comunicar com o cluster e gerar as configurações específicas do ambiente (como segredos e e-mail para certificados).
**Onde executar:** No terminal da sua **máquina local**.

1.  **Execute o Script de Configuração do Ambiente Local**

    Este script interativo automatiza toda a configuração da sua máquina.

    ```bash
    # Dê permissão de execução primeiro
    chmod +x production/scripts/configure-local-env.sh

    # Execute o script
    bash production/scripts/configure-local-env.sh
    ```

    O que este script faz:
    - **Solicita o IP do servidor** e o **e-mail para o Let's Encrypt**.
    - **Configura seu `kubectl`** para apontar para o novo cluster no servidor.
    - **Gera o `cluster-issuers.yaml`**, que instrui o `cert-manager` a emitir certificados SSL/TLS.
    - **Executa `create-all-secrets.sh`** para gerar senhas aleatórias e seguras para Camunda e Grafana, criptografando-as com o `kubeseal`.
    - **Cria um commit no Git** com todos os arquivos de configuração gerados.

2.  **Envie as Configurações para o Repositório**

    O script anterior preparou o commit. Agora, você só precisa enviá-lo para o repositório. Este é o gatilho que inicia a implantação no ArgoCD.

    ```bash
    git push
    ```

---

### Fase 3: Bootstrap das Aplicações no Cluster

**Objetivo:** Instruir o ArgoCD a sincronizar e implantar todas as aplicações definidas no repositório.
**Onde executar:** no servidor.

1.  **Execute o Script de Bootstrap das Aplicações**

    Este comando final aplica o "App of Apps" no cluster, que é o ponto de entrada para o ArgoCD começar a trabalhar.

    ```bash
    bash production/scripts/bootstrap-apps.sh
    ```

    A partir deste momento, o ArgoCD assume o controle e implantará todas as aplicações na ordem correta, respeitando as `Sync Waves`.

2.  **Aplique os Ingresses da Aplicação (Passo Manual)**

    Após o bootstrap, os `Ingresses` que expõem os serviços do Camunda e do próprio ArgoCD precisam ser aplicados manualmente.

    ```bash
    kubectl apply -f production/k8s/ingress/
    ```

    > **Nota:** Atualmente, este é um passo manual. No futuro, ele pode ser automatizado criando uma nova `Application` do ArgoCD para gerenciar os Ingresses.

3.  **Acompanhe o Deploy (Opcional)**

    Você pode observar o progresso da implantação na interface de usuário do ArgoCD. Para obter a senha inicial, execute:
    ```bash
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
    ```
    O Ingress para o ArgoCD será criado automaticamente.

Após a conclusão, todo o ambiente SGP estará no ar, configurado com TLS e pronto para uso.
