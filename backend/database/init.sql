-- ============================================
-- Kubernetes Microservices Project
-- PostgreSQL initialization
-- ============================================


-- ============================================
-- 1. Create tables
-- ============================================

CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE IF NOT EXISTS devices (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,

    user_agent TEXT,
    platform VARCHAR(100),
    screen_width INTEGER,
    screen_height INTEGER,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_devices_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);


-- ============================================
-- 2. Create application user
-- ============================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_catalog.pg_roles
        WHERE rolname = 'app'
    ) THEN
        CREATE ROLE app_user
        LOGIN
        PASSWORD '123';
    END IF;
END
$$;


-- ============================================
-- 3. Database permissions
-- ============================================

GRANT CONNECT ON DATABASE microservices_db
TO app;


-- ============================================
-- 4. Schema permissions
-- ============================================

GRANT USAGE ON SCHEMA public
TO app;


-- ============================================
-- 5. Table permissions
-- ============================================

GRANT SELECT, INSERT, UPDATE, DELETE
ON TABLE users, devices
TO app;


-- ============================================
-- 6. Sequence permissions
-- ============================================

GRANT USAGE, SELECT
ON SEQUENCE users_id_seq, devices_id_seq
TO app;
