-- =============================================================================
-- Create PostgreSQL Roles for MCP Server (Read-Only + Read-Write)
-- =============================================================================
-- Author: Frederick Mbuya
-- License: MIT
--
-- This script creates TWO database roles for the MCP server:
--   1. mcp_readonly  - SELECT only (use now)
--   2. mcp_readwrite - SELECT, INSERT, UPDATE, DELETE (future use)
--
-- Run this script once on each database you want to connect to.
--
-- Usage:
--   psql "postgresql://postgres:PASSWORD@HOST:PORT/DATABASE" -f setup-database-roles.sql
--
-- Or via Supabase dashboard SQL editor
-- =============================================================================

-- =============================================================================
-- PART 1: Read-Only Role (mcp_readonly)
-- =============================================================================
-- Use this role for safe, read-only access to your database

DO $$
BEGIN
  -- Create read-only role
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'mcp_readonly') THEN
    CREATE ROLE mcp_readonly LOGIN PASSWORD 'YOUR_READONLY_PASSWORD_HERE';
    RAISE NOTICE 'Created role: mcp_readonly';
  ELSE
    RAISE NOTICE 'Role mcp_readonly already exists';
  END IF;
END
$$;

-- Grant connection privileges
GRANT CONNECT ON DATABASE postgres TO mcp_readonly;

-- Grant read access to all schemas
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

    RAISE NOTICE 'Granted READ access to schema: %', schema_name;
  END LOOP;
END
$$;

-- Grant access to system views (for schema introspection)
GRANT SELECT ON ALL TABLES IN SCHEMA information_schema TO mcp_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA pg_catalog TO mcp_readonly;

-- Security hardening for read-only role
REVOKE CREATE ON SCHEMA public FROM mcp_readonly;
REVOKE CREATE ON DATABASE postgres FROM mcp_readonly;
ALTER ROLE mcp_readonly NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;

-- For Supabase with RLS: Choose ONE option below

-- Option A: Bypass RLS entirely (simpler, see all data)
-- Uncomment the line below if you want mcp_readonly to bypass RLS:
-- ALTER ROLE mcp_readonly BYPASSRLS;

-- Option B: Respect RLS policies (more secure)
-- Leave above commented out, and create specific RLS policies per table
-- Example:
-- CREATE POLICY mcp_readonly_users_policy ON users
--   FOR SELECT TO mcp_readonly USING (true);

\echo ''
\echo '=========================================='
\echo 'Read-Only Role (mcp_readonly) configured!'
\echo '=========================================='
\echo ''

-- =============================================================================
-- PART 2: Read-Write Role (mcp_readwrite)
-- =============================================================================
-- Use this role when you need write access (INSERT, UPDATE, DELETE)
-- IMPORTANT: Only use with ALLOW_WRITE=true in production!

DO $$
BEGIN
  -- Create read-write role
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'mcp_readwrite') THEN
    CREATE ROLE mcp_readwrite LOGIN PASSWORD 'YOUR_READWRITE_PASSWORD_HERE';
    RAISE NOTICE 'Created role: mcp_readwrite';
  ELSE
    RAISE NOTICE 'Role mcp_readwrite already exists';
  END IF;
END
$$;

-- Grant connection privileges
GRANT CONNECT ON DATABASE postgres TO mcp_readwrite;

-- Grant read-write access to all schemas
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
    EXECUTE format('GRANT USAGE ON SCHEMA %I TO mcp_readwrite;', schema_name);

    -- Grant SELECT, INSERT, UPDATE, DELETE on all existing tables
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA %I TO mcp_readwrite;', schema_name);

    -- Grant same permissions on all future tables
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO mcp_readwrite;', schema_name);

    -- Grant usage and update on sequences (needed for auto-increment)
    EXECUTE format('GRANT USAGE, UPDATE ON ALL SEQUENCES IN SCHEMA %I TO mcp_readwrite;', schema_name);
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT USAGE, UPDATE ON SEQUENCES TO mcp_readwrite;', schema_name);

    RAISE NOTICE 'Granted READ-WRITE access to schema: %', schema_name;
  END LOOP;
END
$$;

-- Grant access to system views
GRANT SELECT ON ALL TABLES IN SCHEMA information_schema TO mcp_readwrite;
GRANT SELECT ON ALL TABLES IN SCHEMA pg_catalog TO mcp_readwrite;

-- Security hardening for read-write role
-- Note: We allow data manipulation but NOT schema changes
REVOKE CREATE ON SCHEMA public FROM mcp_readwrite;
REVOKE CREATE ON DATABASE postgres FROM mcp_readwrite;
ALTER ROLE mcp_readwrite NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;

-- For Supabase with RLS: Choose ONE option below

-- Option A: Bypass RLS entirely (simpler, modify all data)
-- Uncomment the line below if you want mcp_readwrite to bypass RLS:
-- ALTER ROLE mcp_readwrite BYPASSRLS;

-- Option B: Respect RLS policies (more secure)
-- Leave above commented out, and create specific RLS policies per table
-- Example:
-- CREATE POLICY mcp_readwrite_users_policy ON users
--   FOR ALL TO mcp_readwrite USING (true) WITH CHECK (true);

\echo ''
\echo '============================================='
\echo 'Read-Write Role (mcp_readwrite) configured!'
\echo '============================================='
\echo ''

-- =============================================================================
-- PART 3: Verification
-- =============================================================================

\echo ''
\echo '=========================================='
\echo 'VERIFICATION'
\echo '=========================================='
\echo ''

-- Check roles exist and have correct attributes
SELECT
  rolname AS role_name,
  rolsuper AS is_superuser,
  rolcreaterole AS can_create_roles,
  rolcreatedb AS can_create_db,
  rolcanlogin AS can_login,
  rolbypassrls AS bypass_rls
FROM pg_roles
WHERE rolname IN ('mcp_readonly', 'mcp_readwrite')
ORDER BY rolname;

\echo ''
\echo 'Schema permissions for mcp_readonly:'
SELECT
  nspname AS schema_name,
  has_schema_privilege('mcp_readonly', nspname, 'USAGE') AS has_usage
FROM pg_namespace
WHERE nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY nspname;

\echo ''
\echo 'Schema permissions for mcp_readwrite:'
SELECT
  nspname AS schema_name,
  has_schema_privilege('mcp_readwrite', nspname, 'USAGE') AS has_usage
FROM pg_namespace
WHERE nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY nspname;

\echo ''
\echo 'Table permissions in public schema (sample):'
SELECT
  tablename,
  has_table_privilege('mcp_readonly', 'public.' || tablename, 'SELECT') AS readonly_select,
  has_table_privilege('mcp_readwrite', 'public.' || tablename, 'SELECT') AS readwrite_select,
  has_table_privilege('mcp_readwrite', 'public.' || tablename, 'INSERT') AS readwrite_insert,
  has_table_privilege('mcp_readwrite', 'public.' || tablename, 'UPDATE') AS readwrite_update,
  has_table_privilege('mcp_readwrite', 'public.' || tablename, 'DELETE') AS readwrite_delete
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename
LIMIT 10;

-- =============================================================================
-- PART 4: Testing Instructions
-- =============================================================================

\echo ''
\echo '=========================================='
\echo 'TESTING INSTRUCTIONS'
\echo '=========================================='
\echo ''
\echo '1. Test READ-ONLY role:'
\echo '   psql "postgresql://mcp_readonly:YOUR_READONLY_PASSWORD@HOST:PORT/DATABASE"'
\echo '   '
\echo '   Try these queries (should work):'
\echo '     SELECT current_user;'
\echo '     SELECT * FROM your_table LIMIT 5;'
\echo '   '
\echo '   Try these queries (should FAIL):'
\echo '     INSERT INTO your_table VALUES (...);'
\echo '     UPDATE your_table SET ...;'
\echo '     DELETE FROM your_table;'
\echo ''
\echo '2. Test READ-WRITE role:'
\echo '   psql "postgresql://mcp_readwrite:YOUR_READWRITE_PASSWORD@HOST:PORT/DATABASE"'
\echo '   '
\echo '   Try these queries (should work):'
\echo '     SELECT * FROM your_table LIMIT 5;'
\echo '     INSERT INTO your_table VALUES (...);'
\echo '     UPDATE your_table SET ...;'
\echo '     DELETE FROM your_table WHERE ...;'
\echo '   '
\echo '   Try these queries (should FAIL):'
\echo '     CREATE TABLE test (...);'
\echo '     DROP TABLE your_table;'
\echo '     ALTER TABLE your_table ...;'
\echo ''

-- =============================================================================
-- PART 5: Configuration Instructions
-- =============================================================================

\echo ''
\echo '=========================================='
\echo 'MCP SERVER CONFIGURATION'
\echo '=========================================='
\echo ''
\echo 'Update your .env file with BOTH connections:'
\echo ''
\echo '# Read-Only Connection (use now)'
\echo 'CONN_prod_ro_HOST=your-host.supabase.co'
\echo 'CONN_prod_ro_PORT=5432'
\echo 'CONN_prod_ro_DBNAME=postgres'
\echo 'CONN_prod_ro_USER=mcp_readonly'
\echo 'CONN_prod_ro_PASSWORD=YOUR_READONLY_PASSWORD_HERE'
\echo 'CONN_prod_ro_SSLMODE=require'
\echo ''
\echo '# Read-Write Connection (future use with ALLOW_WRITE=true)'
\echo 'CONN_prod_rw_HOST=your-host.supabase.co'
\echo 'CONN_prod_rw_PORT=5432'
\echo 'CONN_prod_rw_DBNAME=postgres'
\echo 'CONN_prod_rw_USER=mcp_readwrite'
\echo 'CONN_prod_rw_PASSWORD=YOUR_READWRITE_PASSWORD_HERE'
\echo 'CONN_prod_rw_SSLMODE=require'
\echo ''
\echo 'OR configure per-connection write access (future enhancement):'
\echo ''
\echo 'CONN_prod_HOST=your-host.supabase.co'
\echo 'CONN_prod_DBNAME=postgres'
\echo 'CONN_prod_USER=mcp_readonly              # Default: read-only'
\echo 'CONN_prod_PASSWORD=YOUR_READONLY_PASSWORD'
\echo ''
\echo 'CONN_prod_rw_HOST=your-host.supabase.co'
\echo 'CONN_prod_rw_DBNAME=postgres'
\echo 'CONN_prod_rw_USER=mcp_readwrite          # Explicit: read-write'
\echo 'CONN_prod_rw_PASSWORD=YOUR_READWRITE_PASSWORD'
\echo ''

-- =============================================================================
-- PART 6: Security Best Practices
-- =============================================================================

\echo ''
\echo '=========================================='
\echo 'SECURITY BEST PRACTICES'
\echo '=========================================='
\echo ''
\echo '1. Use STRONG, DIFFERENT passwords for each role'
\echo '   - Generate with: openssl rand -base64 32'
\echo ''
\echo '2. For production:'
\echo '   - Use mcp_readonly by default'
\echo '   - Only use mcp_readwrite when absolutely necessary'
\echo '   - Consider separate MCP_TOKEN values for each role'
\echo ''
\echo '3. For Supabase with RLS:'
\echo '   - Consider using RLS policies instead of BYPASSRLS'
\echo '   - This provides fine-grained access control per table'
\echo ''
\echo '4. Regular maintenance:'
\echo '   - Rotate passwords quarterly'
\echo '   - Review permissions regularly'
\echo '   - Monitor query logs for suspicious activity'
\echo ''
\echo '5. Network security:'
\echo '   - Use SSL/TLS (SSLMODE=require) for all connections'
\echo '   - Consider IP whitelisting at database level'
\echo '   - Use VPN for remote MCP server access'
\echo ''

\echo ''
\echo '=========================================='
\echo 'Setup complete!'
\echo '=========================================='
\echo ''
\echo 'Next steps:'
\echo '1. Update your .env file with both connection credentials'
\echo '2. Restart MCP server: docker compose restart'
\echo '3. Test connections: ./test-server.sh'
\echo '4. Test read-only access first before enabling writes'
\echo ''
