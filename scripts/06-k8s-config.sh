#!/usr/bin/env bash
# Pasa la configuracion al cluster:
#   Secret rds-credentials  <- Secrets Manager (host, dbname, username, password, port)
#   ConfigMap app-config    <- URL de SQS, tabla de DynamoDB, region y URL de checkout
# Los pods solo leen variables de entorno, nada va hardcodeado en el codigo.
set -euo pipefail
source "$(dirname "$0")/config.sh"

paso "Secret rds-credentials desde Secrets Manager"
SECRETO_JSON="$(aws secretsmanager get-secret-value --secret-id "$SECRETO" --query SecretString --output text)"
kubectl create secret generic rds-credentials \
  --from-literal=host="$(jq -r .host <<<"$SECRETO_JSON")" \
  --from-literal=port="$(jq -r .port <<<"$SECRETO_JSON")" \
  --from-literal=dbname="$(jq -r .dbname <<<"$SECRETO_JSON")" \
  --from-literal=username="$(jq -r .username <<<"$SECRETO_JSON")" \
  --from-literal=password="$(jq -r .password <<<"$SECRETO_JSON")" \
  --dry-run=client -o yaml | kubectl apply -f -

paso "ConfigMap app-config"
kubectl create configmap app-config \
  --from-literal=AWS_REGION="$AWS_REGION" \
  --from-literal=SQS_QUEUE_URL="$(cola_url)" \
  --from-literal=DYNAMODB_TABLE="$TABLA_CONCIERTOS" \
  --from-literal=CHECKOUT_URL="$CHECKOUT_URL" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl get configmap app-config -o jsonpath='{.data}' | jq .

paso "acceso al NodePort $API_NODEPORT de ticket-api"
aws ec2 authorize-security-group-ingress \
  --group-id "$(sg_cluster)" --protocol tcp --port "$API_NODEPORT" --cidr 0.0.0.0/0 >/dev/null 2>&1 || true
echo "puerto $API_NODEPORT abierto en los nodos"
