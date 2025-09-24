#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing k3s (root required)"
bash "$(dirname "$0")/setup-production/bootstrap-k3s.sh"

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "==> Installing Helm"
bash "$(dirname "$0")/setup-production/bootstrap-helm.sh"

echo "==> Installing Argo CD Server Components"
bash "$(dirname "$0")/setup-production/bootstrap-argocd.sh"

echo "==> Installing Argo CD CLI (Client Tool)"
bash "$(dirname "$0")/setup-production/bootstrap-argocd-cli.sh"

echo "==> Installing Sealed Secrets Controller"
bash "$(dirname "$0")/setup-production/install-sealed-secrets.sh"



echo "==> Configuring Argo CD Repository Access (SSH)"
bash "$(dirname "$0")/setup-production/configure-argocd-repo.sh"

echo "All set! A base do ambiente está pronta."
echo "Próximo passo: execute 'bash production/scripts/bootstrap-apps.sh' para que o Argo CD instale todas as aplicações."
