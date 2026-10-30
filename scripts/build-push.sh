#!/usr/bin/env bash
# Construye y sube la imagen de un servicio a ECR. Correr en CloudShell
# (x86_64, igual que los nodos t3.medium).
#
#   bash scripts/build-push.sh ticket-api ruta/al/ticket-api
set -euo pipefail
source "$(dirname "$0")/config.sh"

SERVICIO="${1:?uso: build-push.sh <servicio> <directorio con Dockerfile>}"
CONTEXTO="${2:?falta el directorio con el Dockerfile}"
IMAGEN="${ECR}/${SERVICIO}:latest"

aws ecr get-login-password | docker login --username AWS --password-stdin "$ECR" >/dev/null
docker build -t "$IMAGEN" "$CONTEXTO"
docker push "$IMAGEN"
echo "$IMAGEN"
