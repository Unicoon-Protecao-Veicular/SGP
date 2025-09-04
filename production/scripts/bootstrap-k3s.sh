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
sleep 5

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
