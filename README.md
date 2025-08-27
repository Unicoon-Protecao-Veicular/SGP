# Repositório GitOps – Camunda 8 + Argo CD

Este repositório contém a configuração GitOps utilizada pelo **Argo CD** para gerenciar a implantação da plataforma **Camunda 8** em ambientes Kubernetes.  
A organização do repositório segue uma estrutura baseada em **Helm + Kustomize**, permitindo separar configurações comuns e ajustes específicos por ambiente (**dev**, **staging** e futuro **prod**).

---

## Estrutura de Pastas

```

.
├── apps/                 # Definições de Applications do Argo CD
│   ├── camunda-dev.yaml
│   └── camunda-staging.yaml
│
├── projects/             # Definições de AppProjects (escopo e permissões)
│   ├── dev.yaml
│   └── staging.yaml
│
├── camunda/
│   ├── base/             # Chart base e valores comuns
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── kustomization.yaml
│   │
│   └── overlays/         # Overlays específicos por ambiente
│       ├── dev/
│       │   ├── values-dev.yaml
│       │   ├── ingress.yaml
│       │   ├── network-policy.yaml
│       │   └── kustomization.yaml
│       ├── staging/
│       │   ├── values-staging.yaml
│       │   ├── ingress.yaml
│       │   ├── network-policy.yaml
│       │   └── kustomization.yaml
│       └── prod/         # Esqueleto para ambiente de produção
│
└── src/                  # Artefatos de processos e microserviços
├── bpmn/
├── dmn/
└── microservice-a/

```

---

## Fluxo GitOps

1. **AppProjects**: defina escopo de recursos e namespaces (ex.: `camunda-dev`, `camunda-staging`).  
   Arquivos em: `projects/`.

2. **Applications**: apontam para os overlays correspondentes.  
   Arquivos em: `apps/`.

3. **Argo CD**: sincroniza o estado desejado (declarado neste repositório) com o cluster Kubernetes.  
   - Gera namespaces por ambiente.  
   - Instala Camunda 8 com os componentes habilitados (`zeebe`, `operate`, `tasklist`, `identity`, `optimize`).  
   - Configura **Ingress NGINX** com TLS via Cert-Manager.  
   - Aplica **NetworkPolicy** para isolar namespaces.  

---

## Principais Componentes do Camunda

- **Zeebe**: engine de orquestração de processos.
- **Operate**: monitoramento e troubleshooting de instâncias de processos.
- **Tasklist**: interface para execução de tarefas humanas.
- **Optimize**: relatórios e dashboards de processos.
- **Identity + Keycloak**: autenticação e SSO.
- **Elasticsearch**: armazenamento de dados do Zeebe.

---

## Artefatos de Processo

A pasta `src/` deve conter os artefatos de negócio versionados junto com a infraestrutura:

- `bpmn/` – modelos de processos.  
- `dmn/` – tabelas de decisão.  
- `microservice-a/` – exemplo de microserviço associado.  

---

## Referências

- [Camunda Platform 8](https://camunda.com/platform/)  
- [Argo CD](https://argo-cd.readthedocs.io/)  
- [Helm](https://helm.sh/)  
- [Kustomize](https://kubectl.docs.kubernetes.io/guides/introduction/kustomize/)  

---