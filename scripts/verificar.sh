#!/usr/bin/env bash
# Muestra que recursos de Concertpass existen en la cuenta.
# Despues de teardown.sh todo debe salir como "no existe".
set -uo pipefail
source "$(dirname "$0")/config.sh"

estado() {
  if [[ -n "$2" && "$2" != "None" ]]; then
    printf "  %-22s %s\n" "$1" "$2"
  else
    printf "  %-22s no existe\n" "$1"
  fi
}

paso "recursos de $PROYECTO en $ACCOUNT_ID ($AWS_REGION)"
estado "EKS cluster"      "$(aws eks describe-cluster --name "$CLUSTER" --query cluster.status --output text 2>/dev/null)"
estado "EC2 nodos"        "$(aws ec2 describe-instances --filters "Name=tag:eks:cluster-name,Values=$CLUSTER" "Name=instance-state-name,Values=pending,running,stopping,stopped" --query 'length(Reservations[].Instances[])' --output text 2>/dev/null | sed 's/^0$//')"
estado "CloudFormation"   "$(aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE CREATE_IN_PROGRESS DELETE_IN_PROGRESS --query "StackSummaries[?starts_with(StackName, 'eksctl-${CLUSTER}')].StackName" --output text 2>/dev/null)"
estado "RDS"              "$(aws rds describe-db-instances --db-instance-identifier "$DB_ID" --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null)"
estado "Secrets Manager"  "$(aws secretsmanager describe-secret --secret-id "$SECRETO" --query Name --output text 2>/dev/null)"
estado "SQS FIFO"         "$(aws sqs get-queue-url --queue-name "$COLA" --query QueueUrl --output text 2>/dev/null)"
estado "DynamoDB"         "$(aws dynamodb describe-table --table-name "$TABLA_CONCIERTOS" --query Table.TableStatus --output text 2>/dev/null)"
estado "ECR"              "$(aws ecr describe-repositories --repository-names "${REPOS[@]}" --query 'repositories[].repositoryName' --output text 2>/dev/null)"

if aws eks describe-cluster --name "$CLUSTER" >/dev/null 2>&1; then
  paso "kubectl get nodes"
  kubectl get nodes
fi
