# Database Roles Strategy

**Author:** Frederick Mbuya

This document explains the recommended PostgreSQL role setup for the MCP server, designed to support both current read-only access and future read-write capabilities.

---

## Strategy Overview

Use **two separate database roles** with different permission levels:

| Role | Permissions | Use Case | MCP Token |
|------|------------|----------|-----------|
| `mcp_readonly` | SELECT only | Default, safe querying | `MCP_TOKEN` (current) |
| `mcp_readwrite` | SELECT, INSERT, UPDATE, DELETE | Write operations | `MCP_TOKEN_RW` (future) |

---

## Why Two Roles?

### Security Benefits

1. **Principle of Least Privilege**
   - Most queries only need read access
   - Write access is explicitly opt-in

2. **Defense in Depth**
   - Even if read-only token is compromised, data cannot be modified
   - Separate credentials for different permission levels

3. **Audit Trail**
   - Database logs show which role performed each action
   - Easy to track read vs. write operations

4. **Flexibility**
   - Can use different connections for different purposes
   - Easy to revoke write access without affecting reads

---

## Current Setup (Read-Only)

### Connection Configuration

```bash
# .env file
CONN_prod_HOST=your-host.supabase.co
CONN_prod_PORT=5432
CONN_prod_DBNAME=postgres
CONN_prod_USER=mcp_readonly
CONN_prod_PASSWORD=your_readonly_password
CONN_prod_SSLMODE=require
```

### What You Can Do

✅ SELECT queries
✅ Schema introspection (DESCRIBE, SHOW TABLES, etc.)
✅ View data
✅ Aggregate queries (COUNT, SUM, etc.)
✅ JOIN operations

### What You Cannot Do

❌ INSERT data
❌ UPDATE records
❌ DELETE records
❌ CREATE/DROP tables
❌ ALTER schema
❌ GRANT/REVOKE permissions

---

## Future Setup (Read-Write)

### Option 1: Separate Named Connections (Recommended)

Configure both read-only and read-write connections:

```bash
# .env file

# Read-Only Connection (default)
CONN_prod_ro_HOST=your-host.supabase.co
CONN_prod_ro_DBNAME=postgres
CONN_prod_ro_USER=mcp_readonly
CONN_prod_ro_PASSWORD=readonly_password
CONN_prod_ro_SSLMODE=require

# Read-Write Connection (explicit)
CONN_prod_rw_HOST=your-host.supabase.co
CONN_prod_rw_DBNAME=postgres
CONN_prod_rw_USER=mcp_readwrite
CONN_prod_rw_PASSWORD=readwrite_password
CONN_prod_rw_SSLMODE=require
```

**Usage in Cursor:**
```
Query prod_ro: SELECT * FROM users LIMIT 10    # Read-only, safe
Query prod_rw: INSERT INTO logs VALUES (...)   # Read-write, explicit
```

### Option 2: Global Write Flag (Current Behavior)

```bash
# .env file
ALLOW_WRITE=false  # Global read-only mode
# OR
ALLOW_WRITE=true   # Global read-write mode (all connections)

CONN_prod_HOST=your-host.supabase.co
CONN_prod_USER=mcp_readonly  # Change to mcp_readwrite when ALLOW_WRITE=true
```

### Option 3: Per-Connection Write Flag (Future Enhancement)

Potential future server enhancement:

```bash
# .env file
CONN_prod_ro_HOST=...
CONN_prod_ro_USER=mcp_readonly
CONN_prod_ro_ALLOW_WRITE=false

CONN_prod_rw_HOST=...
CONN_prod_rw_USER=mcp_readwrite
CONN_prod_rw_ALLOW_WRITE=true
```

---

## Implementation Steps

### Step 1: Create Both Roles Now

Run the setup script to create both roles:

```bash
psql "postgresql://postgres:PASSWORD@HOST:PORT/DATABASE" -f setup-database-roles.sql
```

This creates:
- ✅ `mcp_readonly` with SELECT permissions
- ✅ `mcp_readwrite` with SELECT, INSERT, UPDATE, DELETE permissions

### Step 2: Use Read-Only Role (Current)

Configure your .env to use `mcp_readonly`:

```bash
CONN_prod_USER=mcp_readonly
CONN_prod_PASSWORD=your_readonly_password
ALLOW_WRITE=false
```

### Step 3: Add Read-Write When Needed (Future)

When you implement read-write support, you have the role ready:

**Option A: Swap the user**
```bash
CONN_prod_USER=mcp_readwrite  # Change from mcp_readonly
ALLOW_WRITE=true
```

**Option B: Add separate connection**
```bash
# Keep existing read-only connection
CONN_prod_ro_USER=mcp_readonly

# Add new read-write connection
CONN_prod_rw_USER=mcp_readwrite
```

---

## Permission Details

### mcp_readonly Permissions

```sql
-- Schema access
GRANT USAGE ON SCHEMA public TO mcp_readonly;

-- Table access
GRANT SELECT ON ALL TABLES IN SCHEMA public TO mcp_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA information_schema TO mcp_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA pg_catalog TO mcp_readonly;

-- Future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO mcp_readonly;

-- Sequence usage (for info queries)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO mcp_readonly;

-- Restrictions
REVOKE CREATE ON SCHEMA public FROM mcp_readonly;
ALTER ROLE mcp_readonly NOSUPERUSER NOCREATEDB NOCREATEROLE;
```

### mcp_readwrite Permissions

```sql
-- Schema access
GRANT USAGE ON SCHEMA public TO mcp_readwrite;

-- Table access (read + write)
GRANT SELECT, INSERT, UPDATE, DELETE
  ON ALL TABLES IN SCHEMA public
  TO mcp_readwrite;

-- Future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO mcp_readwrite;

-- Sequence usage (for auto-increment)
GRANT USAGE, UPDATE ON ALL SEQUENCES IN SCHEMA public TO mcp_readwrite;

-- Restrictions (no DDL)
REVOKE CREATE ON SCHEMA public FROM mcp_readwrite;
ALTER ROLE mcp_readwrite NOSUPERUSER NOCREATEDB NOCREATEROLE;
```

### What's NOT Granted (Both Roles)

❌ CREATE/DROP/ALTER TABLE (DDL operations)
❌ GRANT/REVOKE permissions
❌ CREATE DATABASE
❌ CREATE ROLE
❌ Superuser privileges
❌ Replication privileges

---

## Supabase-Specific: Row Level Security (RLS)

### Option 1: Bypass RLS (Simpler)

```sql
ALTER ROLE mcp_readonly BYPASSRLS;
ALTER ROLE mcp_readwrite BYPASSRLS;
```

**Pros:**
- Simple setup
- Works immediately
- No per-table configuration

**Cons:**
- Bypasses Supabase's security layer
- Both roles see ALL data regardless of RLS policies

### Option 2: Respect RLS (More Secure)

Create specific policies for MCP roles:

```sql
-- Example: Allow mcp_readonly to see all users
CREATE POLICY mcp_readonly_users_policy ON users
  FOR SELECT
  TO mcp_readonly
  USING (true);

-- Example: Allow mcp_readwrite to modify all users
CREATE POLICY mcp_readwrite_users_policy ON users
  FOR ALL
  TO mcp_readwrite
  USING (true)
  WITH CHECK (true);
```

**Pros:**
- Respects Supabase security model
- Fine-grained control per table
- Can restrict access to specific rows

**Cons:**
- Requires policy setup for each table
- More complex configuration

**Recommendation:** Use BYPASSRLS for internal tools, respect RLS for customer-facing data.

---

## Security Best Practices

### Password Management

1. **Use Different Passwords**
   ```bash
   # Generate strong passwords
   READONLY_PASS=$(openssl rand -base64 32)
   READWRITE_PASS=$(openssl rand -base64 32)
   ```

2. **Store Securely**
   - Use password manager for credentials
   - Never commit .env file to git
   - Use environment variables in production

3. **Rotate Regularly**
   - Quarterly password rotation recommended
   - Update both database and .env file

### Connection Strategy

1. **Default to Read-Only**
   ```bash
   # Most connections should be read-only
   CONN_prod_USER=mcp_readonly
   CONN_staging_USER=mcp_readonly
   CONN_dev_USER=mcp_readonly
   ```

2. **Explicit Write Access**
   ```bash
   # Only add write connections when needed
   CONN_prod_rw_USER=mcp_readwrite  # Separate connection name
   ```

3. **Audit Write Operations**
   - Log all write operations
   - Review regularly for unexpected changes
   - Consider PostgreSQL audit extension

### Network Security

1. **Always Use SSL**
   ```bash
   SSLMODE=require  # For all Supabase connections
   ```

2. **IP Whitelisting**
   - Configure in Supabase dashboard
   - Limit to known MCP server IPs

3. **VPN for Remote Access**
   - Use VPN for remote MCP server
   - Don't expose directly to internet

---

## Testing Your Setup

### Test Read-Only Role

```bash
# Connect as read-only user
psql "postgresql://mcp_readonly:PASSWORD@HOST:PORT/postgres"

# These should work:
SELECT current_user;
SELECT * FROM users LIMIT 5;
SELECT COUNT(*) FROM orders;

# These should FAIL:
INSERT INTO users VALUES (...);
UPDATE users SET email = '...';
DELETE FROM users WHERE id = 1;
CREATE TABLE test (id INT);
```

### Test Read-Write Role

```bash
# Connect as read-write user
psql "postgresql://mcp_readwrite:PASSWORD@HOST:PORT/postgres"

# These should work:
SELECT * FROM users LIMIT 5;
INSERT INTO logs (message) VALUES ('test');
UPDATE users SET last_login = NOW() WHERE id = 1;
DELETE FROM logs WHERE created_at < NOW() - INTERVAL '30 days';

# These should FAIL:
CREATE TABLE test (id INT);
DROP TABLE users;
ALTER TABLE users ADD COLUMN test TEXT;
GRANT SELECT ON users TO public;
```

---

## Migration Path

### Phase 1: Now (Read-Only)
- ✅ Create both roles
- ✅ Use mcp_readonly for all connections
- ✅ ALLOW_WRITE=false globally

### Phase 2: Future (Selective Write)
- Add separate read-write connections
- Keep read-only as default
- Use mcp_readwrite only where needed

### Phase 3: Future Enhancement (Per-Connection Write Control)
- Server enhancement to support per-connection ALLOW_WRITE
- Token-based write access control
- Audit logging for write operations

---

## Frequently Asked Questions

### Q: Why not use one role with conditional permissions?
**A:** Separate roles provide:
- Clear audit trail (role name in logs)
- Defense in depth (separate credentials)
- Easy revocation (drop role or change password)
- Principle of least privilege

### Q: Can I use the same password for both roles?
**A:** Technically yes, but NOT recommended. Use different passwords for:
- Better security if one is compromised
- Clear separation of concerns
- Compliance requirements (SOC2, etc.)

### Q: Do I need both roles if I only use read-only?
**A:** Yes, create both now because:
- Future-proofing (ready when needed)
- No cost to having unused role
- Easier than creating later
- Can test both work correctly

### Q: What about connection pooling?
**A:** Both roles work with connection pooling:
- Use separate pools for read-only vs read-write
- Configure pool size based on expected load
- Read-only pool can be larger (safer)

### Q: How do I revoke access?
**A:** Multiple options:
```sql
-- Option 1: Drop the role entirely
DROP ROLE mcp_readwrite;

-- Option 2: Revoke LOGIN
ALTER ROLE mcp_readwrite NOLOGIN;

-- Option 3: Change password
ALTER ROLE mcp_readwrite PASSWORD 'new_password';

-- Option 4: Revoke permissions
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM mcp_readwrite;
```

---

## Summary

**Current State:**
- Use `mcp_readonly` role
- Read-only access only
- Safe for production

**Future State:**
- `mcp_readonly` for most connections
- `mcp_readwrite` for specific write operations
- Per-connection or per-token write control

**Benefits:**
- ✅ Security by default (read-only)
- ✅ Explicit write access
- ✅ Clear audit trail
- ✅ Future-proof design
- ✅ Flexible configuration

---

**Last Updated:** January 2025
**Version:** 1.0.0
