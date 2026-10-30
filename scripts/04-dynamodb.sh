#!/usr/bin/env bash
# Tabla de conciertos en DynamoDB (solo lectura en runtime) y precarga
set -euo pipefail
source "$(dirname "$0")/config.sh"

paso "tabla DynamoDB $TABLA_CONCIERTOS"
if aws dynamodb describe-table --table-name "$TABLA_CONCIERTOS" >/dev/null 2>&1; then
  echo "ya existe"
else
  aws dynamodb create-table \
    --table-name "$TABLA_CONCIERTOS" \
    --billing-mode PAY_PER_REQUEST \
    --attribute-definitions AttributeName=concert_id,AttributeType=S \
    --key-schema AttributeName=concert_id,KeyType=HASH >/dev/null
  aws dynamodb wait table-exists --table-name "$TABLA_CONCIERTOS"
  echo "creada"
fi

bash "$DIR_SCRIPTS/precarga-dynamodb.sh"
