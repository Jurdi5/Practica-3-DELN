import os
import uuid
from datetime import datetime
import json
import boto3
import psycopg2
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="Ticket API")

DB_HOST = os.getenv("DB_HOST")
DB_NAME = os.getenv("DB_NAME", "concertpass")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_PORT = os.getenv("DB_PORT", "5432")

SQS_QUEUE_URL = os.getenv("SQS_QUEUE_URL")
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")

sqs_client = boto3.client("sqs", region_name=AWS_REGION)

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        port=DB_PORT
    )

class ReserveRequest(BaseModel):
    concert_id: str
    user_id: str
    ticket_type: str
    quantity: int

@app.post("/reserve", status_code=201)
def reserve_ticket(payload: ReserveRequest):
    reservation_id = str(uuid.uuid4())
    now = datetime.utcnow()

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        query = """
            INSERT INTO reservations (reservation_id, concert_id, user_id, ticket_type, quantity, status, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s);
        """
        cur.execute(query, (
            reservation_id,
            payload.concert_id,
            payload.user_id,
            payload.ticket_type,
            payload.quantity,
            "pending",
            now,
            now
        ))
        conn.commit()
        cur.close()
        conn.close()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error insertando en RDS: {str(e)}")

    message_body = {
        "reservation_id": reservation_id,
        "concert_id": payload.concert_id,
        "user_id": payload.user_id,
        "ticket_type": payload.ticket_type,
        "quantity": payload.quantity
    }

    try:
        sqs_client.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(message_body),
            MessageGroupId=payload.concert_id,
            MessageDeduplicationId=reservation_id
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error enviando mensaje a SQS: {str(e)}")

    return {"reservation_id": reservation_id}

@app.get("/reservation/{reservation_id}")
def get_reservation(reservation_id: str):
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        query = "SELECT reservation_id, concert_id, user_id, ticket_type, quantity, status, created_at, updated_at FROM reservations WHERE reservation_id = %s;"
        cur.execute(query, (reservation_id,))
        row = cur.fetchone()
        cur.close()
        conn.close()

        if not row:
            raise HTTPException(status_code=404, detail="Reservación no encontrada")

        return {
            "reservation_id": row[0],
            "concert_id": row[1],
            "user_id": row[2],
            "ticket_type": row[3],
            "quantity": row[4],
            "status": row[5],
            "created_at": str(row[6]),
            "updated_at": str(row[7])
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al consultar RDS: {str(e)}")
