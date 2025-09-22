#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Creating Camunda sealed secret..."
"$SCRIPT_DIR/create-sealed-secret.sh"

echo "Creating Grafana sealed secret..."
"$SCRIPT_DIR/create-grafana-secret.sh"

echo "All secrets created successfully."
