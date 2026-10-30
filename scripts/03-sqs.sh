#!/usr/bin/env bash
# Cola SQS FIFO. ticket-api manda los mensajes con MessageGroupId = concert_id
set -euo pipefail
source "$(dirname "$0")/config.sh"

paso "cola SQS FIFO $COLA"
aws sqs create-queue \
  --queue-name "$COLA" \
  --attributes '{
    "FifoQueue": "true",
    "ContentBasedDeduplication": "true",
    "VisibilityTimeout": "60",
    "ReceiveMessageWaitTimeSeconds": "20",
    "MessageRetentionPeriod": "86400"
  }' >/dev/null

echo "url: $(cola_url)"
