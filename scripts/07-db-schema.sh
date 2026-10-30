#!/usr/bin/env bash
# Crea la tabla reservations en RDS desde un pod del cluster.
# Tambien sirve para comprobar que los pods llegan a RDS.
set -euo pipefail
source "$(dirname "$0")/config.sh"

paso "tabla reservations en RDS"
psql_en_cluster "$(cat "$DIR_SCRIPTS/schema.sql")"
psql_en_cluster "\d reservations"
