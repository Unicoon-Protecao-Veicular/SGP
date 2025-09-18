#!/usr/bin/env bash
set -euo pipefail

# Install k3s on Ubuntu and prepare kubectl access.
# Disables Traefik to use nginx-ingress via Helm.

if ! command -v curl >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y curl
fi

export INSTALL_K3S_EXEC="--disable traefik --write-kubeconfig-mode 644"
curl -sfL https://get.k3s.io | sh -

echo "Waiting for k3s kubeconfig..."
i=0
while [ ! -f /etc/rancher/k3s/k3s.yaml ]; do
  if [ $i -gt 30 ]; then
    echo "Timed out waiting for /etc/rancher/k3s/k3s.yaml" >&2
    exit 1
  fi
  echo "Waiting for kubeconfig file... ($i/30)"
  sleep 2
  i=$((i+1))
done

echo "Waiting for Kubernetes API server to be ready..."
i=0
until /usr/local/bin/k3s kubectl get nodes >/dev/null 2>&1; do
  if [ $i -gt 60 ]; then
    echo "Timed out waiting for Kubernetes API server." >&2
    exit 1
  fi
  echo "Waiting for API server... ($i/60)"
  sleep 2
  i=$((i+1))
done
echo "Kubernetes API server is ready."

KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"
if [ -f "$KUBECONFIG_PATH" ]; then
  # Make kubeconfig available system-wide for all users.
  # k3s was installed with --write-kubeconfig-mode 644 so the file is world-readable.
  CURRENT_EXPORT_LINE='if [ -z "$KUBECONFIG" ]; then export KUBECONFIG=/etc/rancher/k3s/k3s.yaml; fi'
  echo "$CURRENT_EXPORT_LINE" | sudo tee /etc/profile.d/k3s-kubeconfig.sh >/dev/null
  sudo chmod 0644 /etc/profile.d/k3s-kubeconfig.sh

  # Also export for the current shell so subsequent commands (if any) work immediately
  export KUBECONFIG="$KUBECONFIG_PATH"
  echo "KUBECONFIG set system-wide via /etc/profile.d/k3s-kubeconfig.sh"
  echo "Current shell using: $KUBECONFIG_PATH"
else
  echo "k3s kubeconfig not found at $KUBECONFIG_PATH" >&2
  exit 1
fi

# Longhorn prerequisites on Ubuntu (iSCSI + NFS client)
echo "Installing Longhorn prerequisites (open-iscsi, nfs-common)..."
sudo apt-get update -y
sudo apt-get install -y open-iscsi nfs-common
sudo systemctl enable --now iscsid || true
echo "Longhorn prerequisites installed."
