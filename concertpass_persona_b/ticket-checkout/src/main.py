from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="Ticket Checkout API (Simulado)")

class CheckoutRequest(BaseModel):
    reservation_id: str
    quantity: int

@app.post("/checkout")
def process_checkout(payload: CheckoutRequest):
    return {
        "status": "success",
        "message": "Payment authorized",
        "reservation_id": payload.reservation_id
    }
