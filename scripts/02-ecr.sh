#!/usr/bin/env bash
# Repositorios de ECR para las imagenes de los 3 servicios
set -euo pipefail
source "$(dirname "$0")/config.sh"

paso "repositorios ECR"
for repo in "${REPOS[@]}"; do
  if aws ecr describe-repositories --repository-names "$repo" >/dev/null 2>&1; then
    echo "$repo ya existe"
  else
    aws ecr create-repository --repository-name "$repo" >/dev/null
    echo "$repo creado"
  fi
done
echo "registro: $ECR"
