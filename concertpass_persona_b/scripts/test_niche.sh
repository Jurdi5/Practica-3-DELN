#!/bin/bash
API_URL=${1:-"http://localhost:30080"}

echo "=== PROBANDO ESCENARIO DE NICHO (3 reservaciones) ==="

for i in {1..3}
do
  echo "Enviando reservación $i..."
  RESPONSE=$(curl -s -X POST "$API_URL/reserve" \
    -H "Content-Type: application/json" \
    -d '{
      "concert_id": "bad-bunny-gdl",
      "user_id": "usr_niche_'$i'",
      "ticket_type": "vip",
      "quantity": 1
    }')
  
  echo "Respuesta: $RESPONSE"
  RESERVATION_ID=$(echo $RESPONSE | jq -r '.reservation_id')
  
  sleep 1
  echo "Consultando estado inicial de $RESERVATION_ID:"
  curl -s "$API_URL/reservation/$RESERVATION_ID" | jq .
  echo "--------------------------------------------"
done
