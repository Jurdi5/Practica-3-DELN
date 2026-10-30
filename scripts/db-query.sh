#!/usr/bin/env bash
# Consulta RDS desde el cluster. Sin argumentos muestra el resumen por concierto y estado.
#
#   bash scripts/db-query.sh
#   bash scripts/db-query.sh "SELECT * FROM reservations ORDER BY created_at DESC LIMIT 10"
set -euo pipefail
source "$(dirname "$0")/config.sh"

SQL="${1:-SELECT concert_id, ticket_type, status, COUNT(*) AS reservaciones, SUM(quantity) AS boletos
FROM reservations GROUP BY concert_id, ticket_type, status ORDER BY concert_id, ticket_type, status}"

psql_en_cluster "$SQL"
