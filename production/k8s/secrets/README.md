# Gerenciando Segredos com Sealed Secrets

Este guia descreve como criar e gerenciar as senhas do banco de dados de produção usando o Bitnami Sealed Secrets.

## Processo de Criação de Senha

O fluxo de trabalho consiste em criar um Secret padrão do Kubernetes localmente, criptografá-lo usando a CLI `kubeseal` e, em seguida, comitar o `SealedSecret` resultante neste diretório. O controller do Sealed Secrets no cluster irá descriptografá-lo e criar o Secret Kubernetes real.

### 1. Crie um Secret Kubernetes Localmente

Crie um arquivo chamado `postgresql-credentials.yaml` (não o comite no Git) com o seguinte conteúdo:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgresql-credentials
  namespace: camunda
type: Opaque
data:
  # A senha para o usuário 'bn_keycloak'.
  # Substitua 'SUA_SENHA_AQUI' pela senha desejada.
  # O valor deve ser codificado em Base64.
  # Exemplo: echo -n 'SuaSenhaSuperSegura' | base64
  password: SUA_SENHA_EM_BASE64_AQUI

  # A senha para o superusuário 'postgres'.
  # Substitua 'SUA_SENHA_AQUI' pela senha desejada.
  # O valor deve ser codificado em Base64.
  postgres-password: SUA_OUTRA_SENHA_EM_BASE64_AQUI
```

**Importante:**
- Use senhas fortes e diferentes para `password` e `postgres-password`.
- Para gerar o valor em Base64, execute o comando: `echo -n 'SuaSenhaSuperSegura' | base64`

### 2. Criptografe o Secret com `kubeseal`

Com o `kubeseal` e o `kubectl` configurados para apontar para o seu cluster, execute o seguinte comando:

```bash
kubeseal --format=yaml < postgresql-credentials.yaml > sealed-postgresql-credentials.yaml
```

Isso irá:
1.  Buscar a chave pública do controller do Sealed Secrets no seu cluster.
2.  Criptografar o arquivo `postgresql-credentials.yaml`.
3.  Criar um novo arquivo `sealed-postgresql-credentials.yaml`.

### 3. Comite o SealedSecret

O arquivo `sealed-postgresql-credentials.yaml` é seguro para ser comitado no seu repositório Git. Adicione-o a este diretório (`production/k8s/secrets/`).

O ArgoCD irá aplicar este manifesto ao cluster, e o controller do Sealed Secrets irá descriptografá-lo, criando o secret `postgresql-credentials` no namespace `camunda`, pronto para ser usado pelo PostgreSQL e pelo Keycloak.