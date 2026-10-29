import os, json, logging
from decimal import Decimal
import boto3, psycopg2, requests

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("worker")

REGION = os.environ["AWS_REGION"]
QUEUE_URL = os.environ["SQS_QUEUE_URL"]
TABLE = os.environ["DYNAMODB_TABLE"]
CHECKOUT_URL = os.environ["CHECKOUT_URL"]

sqs = boto3.client("sqs", region_name=REGION)
table = boto3.resource("dynamodb", region_name=REGION).Table(TABLE)

def get_conn():
    return psycopg2.connect(
        host=os.environ["DB_HOST"], port=os.environ.get("DB_PORT", 5432),
        dbname=os.environ["DB_NAME"], user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"], connect_timeout=5)

def get_capacity(concert_id, ticket_type):
    item = table.get_item(Key={"concert_id": concert_id}).get("Item")
    if not item:
        return 0
    return int(item["capacity"].get(ticket_type, 0))  # llega como Decimal

def get_status(conn, rid):
    with conn.cursor() as cur:
        cur.execute("SELECT status FROM reservations WHERE reservation_id=%s", (rid,))
        row = cur.fetchone()
    conn.rollback()
    return row[0] if row else None

def set_status(conn, rid, status):
    with conn.cursor() as cur:
        cur.execute("UPDATE reservations SET status=%s, updated_at=NOW() "
                    "WHERE reservation_id=%s", (status, rid))
    conn.commit()

def try_book(conn, m):
    capacity = get_capacity(m["concert_id"], m["ticket_type"])
    try:
        with conn.cursor() as cur:
            cur.execute("""SELECT quantity FROM reservations
                           WHERE concert_id=%s AND ticket_type=%s
                           AND status IN ('booked','confirmed')
                           FOR UPDATE""", (m["concert_id"], m["ticket_type"]))
            sold = sum(r[0] for r in cur.fetchall())
            if sold + m["quantity"] <= capacity:
                cur.execute("UPDATE reservations SET status='booked', updated_at=NOW() "
                            "WHERE reservation_id=%s", (m["reservation_id"],))
                conn.commit()
                return True
        conn.rollback()          # no hay espacio: libera el bloqueo
        return False
    except Exception:
        conn.rollback()
        raise

def process(conn, m):
    rid = m["reservation_id"]
    status = get_status(conn, rid)
    if status in (None, "confirmed", "rejected"):   # idempotencia
        return
    if status == "pending":
        if not try_book(conn, m):
            set_status(conn, rid, "rejected")        # transacción separada
            log.info("rejected %s", rid)
            return
    # status == "booked": llamar a checkout
    r = requests.post(CHECKOUT_URL, timeout=5,
                      json={"reservation_id": rid, "quantity": m["quantity"]})
    if r.status_code == 200:
        set_status(conn, rid, "confirmed")
        log.info("confirmed %s", rid)
    else:
        raise RuntimeError(f"checkout failed: {r.status_code}")

def main():
    conn = get_conn()
    while True:
        resp = sqs.receive_message(QueueUrl=QUEUE_URL, MaxNumberOfMessages=1,
                                   WaitTimeSeconds=20, VisibilityTimeout=60)
        for msg in resp.get("Messages", []):
            try:
                if conn.closed:
                    conn = get_conn()
                process(conn, json.loads(msg["Body"]))
                sqs.delete_message(QueueUrl=QUEUE_URL, ReceiptHandle=msg["ReceiptHandle"])
            except Exception:
                log.exception("error; el mensaje reaparecerá tras el visibility timeout")

if __name__ == "__main__":
    main()
    