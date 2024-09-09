from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import httpx
import random

app = FastAPI()

class PinResponse(BaseModel):
    pin: str

@app.post("/sendpin")
async def send_pin(pin_response: PinResponse):
    # URL and credentials
    url = "https://sunshine:1@localhost:47990/api/pin"
    
    # Prepare data
    data = {"pin": pin_response.pin}
    print(data)
    
    # Make POST request with SSL verification disabled
    async with httpx.AsyncClient(verify=False) as client:
        try:
            response = await client.post(url, json=data)
            response.raise_for_status()  # Raise HTTPError for bad responses
            return {"status": "success", "response": response.json()}
        except httpx.RequestError as exc:
            raise HTTPException(status_code=400, detail=f"Request error: {exc}")
        except httpx.HTTPStatusError as exc:
            raise HTTPException(status_code=exc.response.status_code, detail=f"HTTP error: {exc}")

# To run the app: uvicorn main:app --reload
