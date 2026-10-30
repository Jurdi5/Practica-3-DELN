#!/bin/bash
API_URL=${1:-"http://localhost:30080"}

echo "=== PROBANDO ESCENARIO DE ALTA DEMANDA (Sobrevendido) ==="
echo "Enviando 60 reservaciones rápidas para 'vip' (Capacidad limitada a 50)..."

RESERVATIONS=()

for i in {1..60}
do
  RESPONSE=$(curl -s -X POST "$API_URL/reserve" \
    -H "Content-Type: application/json" \
    -d '{
      "concert_id": "bad-bunny-gdl",
      "user_id": "usr_stress_'$i'",
      "ticket_type": "vip",
      "quantity": 1
    }')
  
  RES_ID=$(echo $RESPONSE | jq -r '.reservation_id')
  if [ "$RES_ID" != "null" ]; then
    RESERVATIONS+=("$RES_ID")
  fi
done

echo "Esperando 10 segundos a que ticket-worker procese la cola de SQS..."
sleep 10

echo "=== VERIFICANDO ESTADOS FINALES ==="
CONFIRMED_COUNT=0
REJECTED_COUNT=0
PENDING_COUNT=0

for id in "${RESERVATIONS[@]}"
do
  STATUS=$(curl -s "$API_URL/reservation/$id" | jq -r '.status')
  if [ "$STATUS" == "confirmed" ] || [ "$STATUS" == "booked" ]; then
    ((CONFIRMED_COUNT++))
  elif [ "$STATUS" == "rejected" ]; then
    ((REJECTED_COUNT++))
  else
    ((PENDING_COUNT++))
  fi
done

echo "Resultados:"
echo " Exitosa / Confirmativas: $CONFIRMED_COUNT"
echo " Rechazadas (rejected): $REJECTED_COUNT"
echo " Aún pendientes: $PENDING_COUNT"
