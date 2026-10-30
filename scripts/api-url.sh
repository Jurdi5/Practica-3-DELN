#!/usr/bin/env bash
# Imprime la URL publica de ticket-api (IP de un nodo + NodePort)
#
#   API=$(bash scripts/api-url.sh)
set -euo pipefail
source "$(dirname "$0")/config.sh" >/dev/null

IP="$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')"
echo "http://${IP}:${API_NODEPORT}"
