from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import psycopg
from pwdlib import PasswordHash

app = FastAPI()

password_hash = PasswordHash.recommended()

DB_CONFIG = {
    "host": "postgres",
    "port": 5432,
    "dbname": "microservices_db",
    "user": "app",
    "password": "123",
}


def get_connection():
    return psycopg.connect(**DB_CONFIG)


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


@app.get("/")
def root():
    return {"message": "User Data Service is running"}


@app.get("/health")
def health():
    try:
        conn = get_connection()
        conn.close()
        return {
            "status": "ok",
            "database": "connected"
        }
    except Exception:
        return {
            "status": "error",
            "database": "disconnected"
        }


@app.post("/users")
def create_user(data: RegisterRequest):

    hashed_password = password_hash.hash(data.password)

    conn = get_connection()

    try:
        with conn.cursor() as cur:

            cur.execute(
                """
                INSERT INTO users (username, password_hash)
                VALUES (%s, %s)
                RETURNING id, username, created_at
                """,
                (data.username, hashed_password)
            )

            user = cur.fetchone()

        conn.commit()

        return {
            "id": user[0],
            "username": user[1],
            "created_at": user[2]
        }

    except psycopg.errors.UniqueViolation:
        conn.rollback()

        raise HTTPException(
            status_code=409,
            detail="Username already exists"
        )

    finally:
        conn.close()


@app.post("/login")
def login(data: LoginRequest):

    conn = get_connection()

    try:
        with conn.cursor() as cur:

            cur.execute(
                """
                SELECT id, username, password_hash
                FROM users
                WHERE username = %s
                """,
                (data.username,)
            )

            user = cur.fetchone()

        if user is None:
            raise HTTPException(
                status_code=401,
                detail="Invalid username or password"
            )

        user_id = user[0]
        username = user[1]
        stored_password = user[2]

        if not password_hash.verify(
            data.password,
            stored_password
        ):
            raise HTTPException(
                status_code=401,
                detail="Invalid username or password"
            )

        return {
            "message": "Login successful",
            "id": user_id,
            "username": username
        }

    finally:
        conn.close()


@app.post("/devices")
def create_device(data: DeviceRequest):

    conn = get_connection()

    try:
        with conn.cursor() as cur:

            cur.execute(
                """
                INSERT INTO devices
                (
                    user_id,
                    user_agent,
                    platform,
                    screen_width,
                    screen_height
                )
                VALUES (%s, %s, %s, %s, %s)
                RETURNING id
                """,
                (
                    data.user_id,
                    data.user_agent,
                    data.platform,
                    data.screen_width,
                    data.screen_height
                )
            )

            device_id = cur.fetchone()[0]

        conn.commit()

        return {
            "message": "Device saved",
            "device_id": device_id
        }

    finally:
        conn.close()
