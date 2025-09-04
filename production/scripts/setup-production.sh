#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing k3s (root required)"
bash "$(dirname "$0")/bootstrap-k3s.sh"

echo "==> Installing Helm"
bash "$(dirname "$0")/bootstrap-helm.sh"

echo "==> Installing Argo CD"
bash "$(dirname "$0")/bootstrap-argocd.sh"

echo "All set. Update DNS and Ingress hosts in production/k8s/ingress/*.yaml and apply them."

