
-- =========================================================
-- 00_create_roles.sql
-- Database Infrastructure Roles Setup
-- Execute as superuser (postgres) once per environment
-- =========================================================

REVOKE ALL ON SCHEMA public FROM PUBLIC;

-- =========================================================
-- Role: platform_owner
-- Owns schemas and database objects. Not used by application.
-- In postgreSQL everything is a role. NOLOGIN makes it pure role. 
-- if it is not there, it is a user who can login.
-- =========================================================
DO $$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'platform_owner') THEN
      CREATE ROLE platform_owner NOLOGIN;
   END IF;
END
$$;

-- =========================================================
-- Role: migration_user
-- Used by Flyway/Liquibase for schema migrations.
-- =========================================================
DO $$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'platform_admin') THEN
      CREATE ROLE platform_admin LOGIN PASSWORD 'admin';
   END IF;
END
$$;

GRANT platform_owner TO platform_admin;
ALTER ROLE platform_admin BYPASSRLS;

-- =========================================================
-- Role: app_user
-- Used by backend application. Subject to RLS.
-- =========================================================
DO $$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_user') THEN
      CREATE ROLE app_user LOGIN PASSWORD 'proxec';
   END IF;
END
$$;

GRANT CONNECT ON DATABASE manufacturing TO app_user;
-- =========================================================
-- Transfer database ownership to platform_user
-- =========================================================
ALTER DATABASE manufacturing OWNER TO platform_owner;
