#!/usr/bin/env bash
# RDS PostgreSQL en las subredes privadas del cluster, accesible solo desde los nodos.
# Las credenciales se generan aqui y se guardan en Secrets Manager. Tarda ~10 minutos.
set -euo pipefail
source "$(dirname "$0")/config.sh"

VPC_ID="$(vpc_cluster)"
SG_CLUSTER="$(sg_cluster)"

paso "security group $DB_SG_NOMBRE"
SG_RDS="$(sg_rds)"
if [[ "$SG_RDS" == "None" || -z "$SG_RDS" ]]; then
  SG_RDS="$(aws ec2 create-security-group \
    --group-name "$DB_SG_NOMBRE" \
    --description "PostgreSQL de concertpass, solo desde el cluster" \
    --vpc-id "$VPC_ID" --query GroupId --output text)"
fi
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_RDS" --protocol tcp --port 5432 --source-group "$SG_CLUSTER" >/dev/null 2>&1 || true
echo "$SG_RDS: 5432 abierto solo para $SG_CLUSTER (nodos del cluster)"

paso "subnet group $DB_SUBNET_GROUP"
SUBNETS="$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:kubernetes.io/role/internal-elb,Values=1" \
  --query "Subnets[].SubnetId" --output text)"
if ! aws rds describe-db-subnet-groups --db-subnet-group-name "$DB_SUBNET_GROUP" >/dev/null 2>&1; then
  # shellcheck disable=SC2086
  aws rds create-db-subnet-group \
    --db-subnet-group-name "$DB_SUBNET_GROUP" \
    --db-subnet-group-description "Subredes privadas de concertpass" \
    --subnet-ids $SUBNETS >/dev/null
fi
echo "subredes privadas: $SUBNETS"

paso "secreto $SECRETO"
if aws secretsmanager describe-secret --secret-id "$SECRETO" >/dev/null 2>&1; then
  DB_PASSWORD="$(aws secretsmanager get-secret-value --secret-id "$SECRETO" --query SecretString --output text | jq -r .password)"
  echo "ya existe, se reutiliza la contrasena"
else
  DB_PASSWORD="$(openssl rand -hex 16)"
  aws secretsmanager create-secret \
    --name "$SECRETO" \
    --description "Credenciales de RDS de concertpass" \
    --secret-string "$(jq -n --arg u "$DB_USUARIO" --arg p "$DB_PASSWORD" --arg d "$DB_NOMBRE" \
      '{engine: "postgres", username: $u, password: $p, dbname: $d, host: "", port: "5432"}')" >/dev/null
  echo "creado"
fi

paso "instancia RDS $DB_ID"
if aws rds describe-db-instances --db-instance-identifier "$DB_ID" >/dev/null 2>&1; then
  echo "ya existe"
else
  aws rds create-db-instance \
    --db-instance-identifier "$DB_ID" \
    --engine postgres \
    --db-instance-class "$DB_CLASE" \
    --allocated-storage 20 \
    --storage-type gp2 \
    --db-name "$DB_NOMBRE" \
    --master-username "$DB_USUARIO" \
    --master-user-password "$DB_PASSWORD" \
    --db-subnet-group-name "$DB_SUBNET_GROUP" \
    --vpc-security-group-ids "$SG_RDS" \
    --no-publicly-accessible \
    --no-multi-az \
    --backup-retention-period 0 \
    --no-deletion-protection >/dev/null
  echo "creando, esperando a que este disponible..."
fi
aws rds wait db-instance-available --db-instance-identifier "$DB_ID"

DB_HOST="$(aws rds describe-db-instances --db-instance-identifier "$DB_ID" \
  --query "DBInstances[0].Endpoint.Address" --output text)"

aws secretsmanager put-secret-value \
  --secret-id "$SECRETO" \
  --secret-string "$(jq -n --arg u "$DB_USUARIO" --arg p "$DB_PASSWORD" --arg d "$DB_NOMBRE" --arg h "$DB_HOST" \
    '{engine: "postgres", username: $u, password: $p, dbname: $d, host: $h, port: "5432"}')" >/dev/null

echo "host: $DB_HOST"
