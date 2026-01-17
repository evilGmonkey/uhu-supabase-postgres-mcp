-- =============================================================================
-- Create Read-Only PostgreSQL Role for MCP Server
-- =============================================================================
-- Author: Frederick Mbuya
-- License: MIT
--
-- This script creates a read-only database role suitable for the MCP server.
-- Run this script once on each database you want to connect to.
--
-- Usage:
--   psql "postgresql://postgres:PASSWORD@HOST:PORT/DATABASE" -f setup-readonly-role.sql
--
-- Or via Supabase dashboard SQL editor
-- =============================================================================

-- =============================================================================
-- Step 1: Create the read-only role
-- =============================================================================
-- Replace 'YOUR_SECURE_PASSWORD' with a strong password
-- This password will be used in your .env file as CONN_*_PASSWORD

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'mcp_readonly') THEN
    CREATE ROLE mcp_readonly LOGIN PASSWORD 'YOUR_SECURE_PASSWORD';
    RAISE NOTICE 'Created role: mcp_readonly';
  ELSE
    RAISE NOTICE 'Role mcp_readonly already exists';
  END IF;
END
$$;

-- =============================================================================
-- Step 2: Grant connection privileges
-- =============================================================================
GRANT CONNECT ON DATABASE postgres TO mcp_readonly;

-- =============================================================================
-- Step 3: Grant read access to all schemas (except system schemas)
-- =============================================================================
-- This will grant USAGE on schemas and SELECT on all tables

DO $$
DECLARE
  schema_name text;
BEGIN
  FOR schema_name IN
    SELECT nspname
    FROM pg_namespace
    WHERE nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
      AND nspname NOT LIKE 'pg_temp%'
      AND nspname NOT LIKE 'pg_toast_temp%'
  LOOP
    -- Grant schema usage
    EXECUTE format('GRANT USAGE ON SCHEMA %I TO mcp_readonly;', schema_name);

    -- Grant SELECT on all existing tables
    EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %I TO mcp_readonly;', schema_name);

    -- Grant SELECT on all future tables
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT ON TABLES TO mcp_readonly;', schema_name);

    -- Grant usage on sequences (for querying sequence info)
    EXECUTE format('GRANT USAGE ON ALL SEQUENCES IN SCHEMA %I TO mcp_readonly;', schema_name);

    RAISE NOTICE 'Granted read access to schema: %', schema_name;
  END LOOP;
END
$$;

-- =============================================================================
-- Step 4: Grant access to system views (for schema introspection)
-- =============================================================================
-- These are needed for queries like "show tables", "describe table", etc.

GRANT SELECT ON ALL TABLES IN SCHEMA information_schema TO mcp_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA pg_catalog TO mcp_readonly;

-- =============================================================================
-- Step 5: Supabase-specific settings (optional)
-- =============================================================================
-- For Supabase databases with Row Level Security (RLS), you have two options:

-- Option A: Bypass RLS entirely (simpler, but less secure)
-- Uncomment the line below if you want the MCP role to see all data:
-- ALTER ROLE mcp_readonly BYPASSRLS;

-- Option B: Create specific RLS policies (more secure)
-- For each table with RLS, create a policy that allows mcp_readonly to read.
-- Example for a 'users' table:
--
-- CREATE POLICY mcp_readonly_users_policy ON users
--   FOR SELECT
--   TO mcp_readonly
--   USING (true);
--
-- Repeat for each table that has RLS enabled.

-- =============================================================================
-- Step 6: Security hardening (optional but recommended)
-- =============================================================================

-- Prevent the role from creating new objects
REVOKE CREATE ON SCHEMA public FROM mcp_readonly;
REVOKE CREATE ON DATABASE postgres FROM mcp_readonly;

-- Ensure the role cannot become a superuser
ALTER ROLE mcp_readonly NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;

-- =============================================================================
-- Verification Queries
-- =============================================================================
-- Run these queries to verify the setup:

-- Check role exists and has correct attributes
SELECT
  rolname,
  rolsuper,
  rolinherit,
  rolcreaterole,
  rolcreatedb,
  rolcanlogin,
  rolconnlimit,
  rolbypassrls
FROM pg_roles
WHERE rolname = 'mcp_readonly';

-- Check schema permissions
SELECT
  nspname AS schema_name,
  has_schema_privilege('mcp_readonly', nspname, 'USAGE') AS has_usage
FROM pg_namespace
WHERE nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY nspname;

-- Check table permissions in public schema
SELECT
  schemaname,
  tablename,
  has_table_privilege('mcp_readonly', schemaname || '.' || tablename, 'SELECT') AS has_select
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- =============================================================================
-- Testing the Role
-- =============================================================================
-- To test the role, connect as mcp_readonly:
--
-- psql "postgresql://mcp_readonly:YOUR_SECURE_PASSWORD@HOST:PORT/DATABASE"
--
-- Then try some queries:
--   SELECT current_user;
--   SELECT current_database();
--   \dt public.*
--   SELECT * FROM your_table LIMIT 5;
--
-- These should work ✓
--
-- Try write operations (these should FAIL):
--   INSERT INTO your_table VALUES (...);  -- Should fail
--   UPDATE your_table SET ...;             -- Should fail
--   DELETE FROM your_table;                -- Should fail
--   DROP TABLE your_table;                 -- Should fail
-- =============================================================================

-- =============================================================================
-- Post-Setup Notes
-- =============================================================================
--
-- 1. Update your .env file with the connection details:
--    CONN_<name>_HOST=your-host.supabase.co
--    CONN_<name>_PORT=5432
--    CONN_<name>_DBNAME=postgres
--    CONN_<name>_USER=mcp_readonly
--    CONN_<name>_PASSWORD=YOUR_SECURE_PASSWORD
--    CONN_<name>_SSLMODE=require
--
-- 2. Restart your MCP server:
--    docker compose restart
--
-- 3. Test the connection:
--    curl http://localhost:8799/healthz
--
-- 4. For multiple databases, repeat this script on each database.
--
-- 5. Consider setting up password rotation for the mcp_readonly role.
--
-- =============================================================================

\echo ''
\echo '==============================================================================='
\echo 'Setup complete!'
\echo '==============================================================================='
\echo 'Next steps:'
\echo '1. Update your .env file with the mcp_readonly credentials'
\echo '2. Restart the MCP server: docker compose restart'
\echo '3. Test the connection: curl http://localhost:8799/healthz'
\echo '==============================================================================='
\echo ''
