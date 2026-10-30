#!/usr/bin/env bash
# Levanta toda la infraestructura de Concertpass en orden.
# Pensado para AWS CloudShell dentro de AWS Academy. Tarda ~30 minutos.
#
#   bash scripts/setup.sh
#
# Cada paso se puede correr por separado y se puede repetir sin romper nada.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

bash "$DIR/00-herramientas.sh"
export PATH="$HOME/bin:$PATH"

bash "$DIR/01-cluster.sh"
bash "$DIR/02-ecr.sh"
bash "$DIR/03-sqs.sh"
bash "$DIR/04-dynamodb.sh"
bash "$DIR/05-rds.sh"
bash "$DIR/06-k8s-config.sh"
bash "$DIR/07-db-schema.sh"

bash "$DIR/verificar.sh"

echo
echo "infraestructura lista. siguiente paso: subir las imagenes a ECR y aplicar los manifiestos de k8s/"
