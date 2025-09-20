# Ambiente de Produção

Este diretório contém os artefatos de implantação para produção.

## Estrutura

- `argocd`: Aplicações do Argo CD (project, app-of-apps, apps)
- `helm-values`: Valores customizados para charts Helm
- `k8s/`: Manifests do Kubernetes (Deployments, Services, Ingress, ConfigMaps, Secrets templates)
- `scripts`: Scripts de bootstrap (k3s, helm, argocd)

## Como usar

1) Provisionar o cluster (k3s) no VPS Ubuntu

   - Instale as ferramentas: `bash production/scripts/setup-production.sh`

   Observação (multiusuários): o script de k3s configura o `KUBECONFIG` de forma global via `/etc/profile.d/k3s-kubeconfig.sh`,
   apontando para `/etc/rancher/k3s/k3s.yaml` (permissão 0644). Assim, qualquer usuário poderá usar `kubectl` sem depender de `~/.kube/config`.
   Abra uma nova sessão de shell após a instalação ou execute `source /etc/profile.d/k3s-kubeconfig.sh` para ativar na sessão atual.

2) Aplicar namespaces e Argo CD App-of-Apps

   - `bash production/scripts/bootstrap-apps.sh`

   O Argo CD irá sincronizar automaticamente:
   - `longhorn` (provisionador de volumes)
   - `ingress-nginx` (LoadBalancer)
   - `kube-prometheus-stack` (Prometheus, Alertmanager, Grafana)
   - `camunda-platform` (Zeebe, Operate, Tasklist, Optimize, Identity, Keycloak, Elasticsearch)

3) Ajustar DNS/Ingress

   - Aplique: `kubectl apply -f production/k8s/ingress/`.

## SSL/TLS com Let's Encrypt

- Instalar cert-manager:
  - `bash production/scripts/install-cert-manager.sh`

- Configurar ClusterIssuers (staging e produção):
  - `LE_EMAIL=seu-email@dominio.com bash production/scripts/configure-lets-encrypt.sh`

- Habilitar TLS nos Ingresses:
  - Os manifests em `production/k8s/ingress/` já incluem a annotation `cert-manager.io/cluster-issuer: letsencrypt-prod` e blocos `tls` com secrets (`argocd-tls`, `camunda-tls`).
  - Ajuste os hosts conforme seu domínio e aplique: `kubectl apply -f production/k8s/ingress/`.

- Renovação e status:
  - Renovação é automática (cert-manager renova antes de expirar).
  - Ver status e forçar renovação manual, se necessário: `bash production/scripts/renew-certificates.sh [--force]`


4) Acesso inicial

   - Argo CD: `argocd.consultorunicoon.com.br` (obter o password `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo`).
   - Grafana: service `monitoring-grafana`. Defina a senha com um Secret antes (abaixo).
   - Camunda UIs (via paths): `consultorunicoon.com.br/operate`, `consultorunicoon.com.br/tasklist`, `consultorunicoon.com.br/optimize`, `consultorunicoon.com.br/identity`, `consultorunicoon.com.br/keycloak`.

Observações importantes:

- Defina segredos reais via `Secret` (não commitar valores). Para Grafana/Keycloak/Identity, configure usuários/senhas/domínios conforme sua política.

## Observações

- Este repositório não deve conter segredos reais.
- Recomenda-se usar pipelines (CI/CD) para aplicar as mudanças.

## Senha do admin do Grafana (segura)

O chart está configurado para usar um Secret existente (`grafana-admin`) em `monitoring`:

1) Crie o Secret com usuário/senha (fora do Git):

   kubectl -n monitoring create secret generic grafana-admin \
     --from-literal=admin-user=admin \
     --from-literal=admin-password='<SENHA_FORTE>'

2) Sincronize/instale o app de monitoring pelo Argo CD. O Grafana usará esse Secret.





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

1.  **Executar o Setup Principal**: O script principal orquestra a instalação de todas as dependências de infraestrutura.
    ```bash
    bash production/scripts/setup-production.sh
    ```
    Este script irá instalar: K3s, Helm, ArgoCD e o controller do Sealed Secrets.

2.  **Gerar o Segredo do Banco de Dados na sua máquina**: As senhas do banco de dados não são armazenadas no Git. Você precisa gerá-las e criptografá-las usando o script que preparamos rodando na sua máquina local.
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