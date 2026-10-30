#!/usr/bin/env bash
# shellcheck disable=SC2034
# Variables compartidas por todos los scripts. Ningun servicio lee de aqui,
# los pods reciben la configuracion por variables de entorno (Secret y ConfigMap).

export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_PAGER=""
export PATH="$HOME/bin:$PATH"

PROYECTO="concertpass"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

# En AWS Academy no se pueden crear roles, se usa LabRole para el cluster y los nodos
LAB_ROLE_ARN="${LAB_ROLE_ARN:-arn:aws:iam::${ACCOUNT_ID}:role/LabRole}"

CLUSTER="${PROYECTO}"
ZONAS="us-east-1a,us-east-1b"
NODO_TIPO="t3.medium"
NODOS=2

COLA="${PROYECTO}-reservations.fifo"
TABLA_CONCIERTOS="concerts"

ECR="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
REPOS=(ticket-api ticket-worker ticket-checkout)

DB_ID="${PROYECTO}-db"
DB_NOMBRE="concertpass"
DB_USUARIO="concertpass"
DB_CLASE="db.t3.micro"
DB_SUBNET_GROUP="${PROYECTO}-db-subnets"
DB_SG_NOMBRE="${PROYECTO}-rds-sg"
SECRETO="${PROYECTO}/rds"

API_NODEPORT=30080
CHECKOUT_URL="http://ticket-checkout-service:8000/checkout"

DIR_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

paso() { echo; echo "==> $*"; }

vpc_cluster() {
  aws eks describe-cluster --name "$CLUSTER" --query cluster.resourcesVpcConfig.vpcId --output text
}

sg_cluster() {
  aws eks describe-cluster --name "$CLUSTER" --query cluster.resourcesVpcConfig.clusterSecurityGroupId --output text
}

sg_rds() {
  aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${DB_SG_NOMBRE}" \
    --query "SecurityGroups[0].GroupId" --output text 2>/dev/null
}

cola_url() {
  aws sqs get-queue-url --queue-name "$COLA" --query QueueUrl --output text
}

# Corre un comando SQL en RDS desde un pod del cluster (RDS no es publica).
# Usa el Secret rds-credentials, la contrasena nunca pasa por la terminal.
psql_en_cluster() {
  local sql="$1" pod="psql-$RANDOM"
  local overrides
  overrides="$(jq -n --arg sql "$sql" --arg pod "$pod" '{
    spec: {
      restartPolicy: "Never",
      containers: [{
        name: $pod,
        image: "postgres:16-alpine",
        command: ["psql", "-v", "ON_ERROR_STOP=1", "-P", "pager=off", "-c", $sql],
        env: [
          {name: "PGHOST",     valueFrom: {secretKeyRef: {name: "rds-credentials", key: "host"}}},
          {name: "PGDATABASE", valueFrom: {secretKeyRef: {name: "rds-credentials", key: "dbname"}}},
          {name: "PGUSER",     valueFrom: {secretKeyRef: {name: "rds-credentials", key: "username"}}},
          {name: "PGPASSWORD", valueFrom: {secretKeyRef: {name: "rds-credentials", key: "password"}}}
        ]
      }]
    }
  }')"
  kubectl run "$pod" --rm -i --quiet --restart=Never --image=postgres:16-alpine --overrides="$overrides"
}
