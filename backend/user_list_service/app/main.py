from fastapi import FastAPI
import psycopg

app = FastAPI()

DB_CONFIG = {
    "host": "postgres",
    "port": 5432,
    "dbname": "microservices_db",
    "user": "app",
    "password": "123",
}


def get_connection():
    return psycopg.connect(**DB_CONFIG)


@app.get("/")
def root():
    return {"message": "User List Service is running"}


@app.get("/users")
def get_users():

    conn = get_connection()

    try:
        with conn.cursor() as cur:

            cur.execute(
                """
                SELECT id, username, created_at
                FROM users
                ORDER BY id
                """
            )

            rows = cur.fetchall()

        return [
            {
                "id": row[0],
                "username": row[1],
                "created_at": row[2]
            }
            for row in rows
        ]

    finally:
        conn.close()
