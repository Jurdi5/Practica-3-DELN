#!/usr/bin/env bash
# Destruye todos los recursos de Concertpass. EKS y RDS cobran por hora,
# correr esto al terminar de trabajar. Tarda ~20 minutos.
#
#   bash scripts/teardown.sh        (pide confirmacion)
#   bash scripts/teardown.sh -y     (sin confirmacion)
set -uo pipefail
source "$(dirname "$0")/config.sh"

if [[ "${1:-}" != "-y" ]]; then
  read -r -p "se va a borrar toda la infraestructura de ${PROYECTO} en la cuenta ${ACCOUNT_ID}. escribe 'borrar' para seguir: " ok
  [[ "$ok" == "borrar" ]] || exit 1
fi

CLUSTER_EXISTE=false
aws eks describe-cluster --name "$CLUSTER" >/dev/null 2>&1 && CLUSTER_EXISTE=true

if $CLUSTER_EXISTE; then
  paso "servicios de kubernetes"
  aws eks update-kubeconfig --name "$CLUSTER" >/dev/null 2>&1
  kubectl delete deployments --all --ignore-not-found --timeout=60s
  kubectl delete services --field-selector metadata.name!=kubernetes --ignore-not-found --timeout=120s
fi

paso "RDS $DB_ID"
if aws rds describe-db-instances --db-instance-identifier "$DB_ID" >/dev/null 2>&1; then
  aws rds delete-db-instance \
    --db-instance-identifier "$DB_ID" \
    --skip-final-snapshot \
    --delete-automated-backups >/dev/null
  echo "borrando, esperando..."
  aws rds wait db-instance-deleted --db-instance-identifier "$DB_ID"
fi
aws rds delete-db-subnet-group --db-subnet-group-name "$DB_SUBNET_GROUP" 2>/dev/null && echo "subnet group borrado"

SG_RDS="$(sg_rds)"
if [[ -n "$SG_RDS" && "$SG_RDS" != "None" ]]; then
  aws ec2 delete-security-group --group-id "$SG_RDS" && echo "security group $SG_RDS borrado"
fi

paso "Secrets Manager $SECRETO"
aws secretsmanager delete-secret --secret-id "$SECRETO" --force-delete-without-recovery >/dev/null 2>&1 && echo "borrado"

paso "SQS $COLA"
URL="$(aws sqs get-queue-url --queue-name "$COLA" --query QueueUrl --output text 2>/dev/null)"
[[ -n "$URL" ]] && aws sqs delete-queue --queue-url "$URL" && echo "borrada"

paso "DynamoDB $TABLA_CONCIERTOS"
if aws dynamodb delete-table --table-name "$TABLA_CONCIERTOS" >/dev/null 2>&1; then
  aws dynamodb wait table-not-exists --table-name "$TABLA_CONCIERTOS"
  echo "borrada"
fi

paso "ECR"
for repo in "${REPOS[@]}"; do
  aws ecr delete-repository --repository-name "$repo" --force >/dev/null 2>&1 && echo "$repo borrado"
done

if $CLUSTER_EXISTE; then
  paso "cluster $CLUSTER (nodos, VPC y CloudFormation)"
  eksctl delete cluster --name "$CLUSTER" --region "$AWS_REGION" --wait
fi

bash "$(dirname "$0")/verificar.sh"
