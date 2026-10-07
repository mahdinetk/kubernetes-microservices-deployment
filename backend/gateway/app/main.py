from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import httpx

app = FastAPI()

USER_DATA_SERVICE = "http://user-data-service:8001"
USER_LIST_SERVICE = "http://user-list-service:8002"


class RegisterRequest(BaseModel):
    username: str
    password: str


class LoginRequest(BaseModel):
    username: str
    password: str


class DeviceRequest(BaseModel):
    user_id: int
    user_agent: str
    platform: str
    screen_width: int
    screen_height: int


class LoginRequest(BaseModel):
    username: str
    password: str


@app.get("/")
def root():
    return {"message": "Gateway is running"}


@app.post("/api/register")
async def register(data: RegisterRequest):

    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{USER_DATA_SERVICE}/users",
            json=data.model_dump()
        )

    if response.status_code != 200:
        raise HTTPException(
            status_code=response.status_code,
            detail=response.json().get("detail", "Registration failed")
        )

    return response.json()


@app.get("/api/users")
async def get_users():

    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{USER_LIST_SERVICE}/users"
        )

    if response.status_code != 200:
        raise HTTPException(
            status_code=500,
            detail="User List Service unavailable"
        )

    return response.json()


@app.post("/api/user/device")
async def save_device(data: DeviceRequest):

    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{USER_DATA_SERVICE}/devices",
            json=data.model_dump()
        )

    if response.status_code != 200:
        raise HTTPException(
            status_code=response.status_code,
            detail="Could not save device"
        )

    return response.json()


@app.post("/api/login")
async def login(data: LoginRequest):

    async with httpx.AsyncClient() as client:

        response = await client.post(
            f"{USER_DATA_SERVICE}/login",
            json=data.model_dump()
        )

    if response.status_code != 200:
        raise HTTPException(
            status_code=response.status_code,
            detail=response.json().get(
                "detail",
                "Login failed"
            )
        )

    return response.json()
