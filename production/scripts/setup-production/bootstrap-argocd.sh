#!/usr/bin/env bash
set -euo pipefail

kubectl create namespace argocd 2>/dev/null || true

# Install Argo CD using the official manifest
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD pods to become ready..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

cat <<EOF

Argo CD installed.
- Get initial admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
- Optional ingress will be applied by app-of-apps. You can port-forward meanwhile:
  kubectl -n argocd port-forward svc/argocd-server 8080:80
  Then open: http://localhost:8080

EOF

