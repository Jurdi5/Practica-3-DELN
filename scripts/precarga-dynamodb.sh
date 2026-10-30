#!/usr/bin/env bash
# Precarga los conciertos. Se puede correr varias veces, sobreescribe los items.
#   bad-bunny-gdl     -> alta demanda (vip de 50 para probar sobreventa)
#   cuarteto-nos-gdl  -> nicho, capacidades chicas
#   natalia-lafourcade-mty -> tercer concierto con otras capacidades
set -euo pipefail
source "$(dirname "$0")/config.sh"

concierto() {
  local id="$1" nombre="$2" fecha="$3" recinto="$4" floor="$5" vip="$6" general="$7"
  aws dynamodb put-item --table-name "$TABLA_CONCIERTOS" --item "$(jq -n \
    --arg id "$id" --arg nombre "$nombre" --arg fecha "$fecha" --arg recinto "$recinto" \
    --arg floor "$floor" --arg vip "$vip" --arg general "$general" '{
      concert_id: {S: $id},
      name:       {S: $nombre},
      date:       {S: $fecha},
      recinto:    {S: $recinto},
      capacity:   {M: {floor: {N: $floor}, vip: {N: $vip}, general: {N: $general}}}
    }')"
  printf "  %-24s floor=%-4s vip=%-4s general=%s\n" "$id" "$floor" "$vip" "$general"
}

paso "precarga de conciertos en $TABLA_CONCIERTOS"
concierto "bad-bunny-gdl"          "Bad Bunny Debi tirar mas fotos" "2026-11-15" "Estadio Akron, GDL"       100 50 500
concierto "cuarteto-nos-gdl"       "El Cuarteto de Nos"             "2026-11-22" "C3 Stage, GDL"            20  10 80
concierto "natalia-lafourcade-mty" "Natalia Lafourcade"             "2026-12-05" "Auditorio Citibanamex, MTY" 60  30 200
