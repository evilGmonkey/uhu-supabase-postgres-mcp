# Quick Start Guide

Get your Supabase Postgres MCP Server running in 5 minutes!

---

## Prerequisites Checklist

- [ ] Git installed
- [ ] Docker and docker-compose installed
- [ ] Access to your Supabase/PostgreSQL database(s)
- [ ] Database credentials (host, port, database name, user, password)
- [ ] Cursor IDE (or another MCP-compatible client)

---

## Step 1: Clone Repository (30 seconds)

```bash
# Clone from GitHub
git clone https://github.com/evilGmonkey/uhu-supabase-postgres-mcp.git

# Navigate to server directory
cd uhu-supabase-postgres-mcp/supabase-postgres-mcp-server
```

---

## Step 2: Configure Environment (2 minutes)

```bash
# 1. Copy environment template
cp .env.example .env

# 2. Generate a strong MCP token
export MCP_TOKEN=$(openssl rand -base64 32)
echo "Your MCP_TOKEN: $MCP_TOKEN"

# 3. Update .env file with the generated token
sed -i "s/MCP_TOKEN=CHANGE_ME_TO_A_STRONG_RANDOM_TOKEN/MCP_TOKEN=$MCP_TOKEN/" .env

# 4. Edit .env to add your database credentials
nano .env  # or use your favorite editor
```

**Minimum required configuration:**

After running the commands above, your .env will have MCP_TOKEN set. Now add your database connections. You'll configure BOTH read-only and read-write connections (passwords will be set in Step 3):

```bash
# MCP_TOKEN is already set from step 2 above
MCP_TOKEN=<generated-token-from-step-2>

# Read-Only Connection (safe, default)
CONN_prod_ro_HOST=your-supabase-host.supabase.co
CONN_prod_ro_DBNAME=postgres
CONN_prod_ro_USER=mcp_readonly
CONN_prod_ro_PASSWORD=<will-be-set-in-step-3>
CONN_prod_ro_SSLMODE=require

# Read-Write Connection (for testing writes)
CONN_prod_rw_HOST=your-supabase-host.supabase.co
CONN_prod_rw_DBNAME=postgres
CONN_prod_rw_USER=mcp_readwrite
CONN_prod_rw_PASSWORD=<will-be-set-in-step-3>
CONN_prod_rw_SSLMODE=require
```

**Note:** You can use the same host for both connections - they differ only by USER and PASSWORD.

**Alternative for Windows (PowerShell):**

```powershell
# 1. Copy environment template
cp .env.example .env

# 2. Generate a strong MCP token
$MCP_TOKEN = [Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Maximum 256 }))
Write-Host "Your MCP_TOKEN: $MCP_TOKEN"

# 3. Update .env file with the generated token
(Get-Content .env) -replace 'MCP_TOKEN=CHANGE_ME_TO_A_STRONG_RANDOM_TOKEN', "MCP_TOKEN=$MCP_TOKEN" | Set-Content .env

# 4. Edit .env to add your database credentials
notepad .env
```

**Important notes:**
- The MCP_TOKEN is automatically generated and inserted into .env
- Replace `prod` with any name you want (staging, dev, office, etc.)
- Use `SSLMODE=require` for Supabase connections
- Keep `ALLOW_WRITE=false` (read-only is safer)

---

## Step 3: Setup Database Roles (1 minute)

**Recommended:** Run the comprehensive setup script to create BOTH roles:

```bash
# Generate strong passwords for both roles
export READONLY_PASS=$(openssl rand -base64 32)
export READWRITE_PASS=$(openssl rand -base64 32)

echo "Read-Only Password: $READONLY_PASS"
echo "Read-Write Password: $READWRITE_PASS"

# Run the setup script (creates both mcp_readonly and mcp_readwrite)
psql "postgresql://postgres:YOUR_POSTGRES_PASSWORD@HOST:PORT/DATABASE" \
  -f setup-database-roles.sql
```

**Alternative - Quick Manual Setup (creates both roles):**

```sql
-- Read-Only Role
CREATE ROLE mcp_readonly LOGIN PASSWORD 'your-readonly-password';
GRANT CONNECT ON DATABASE postgres TO mcp_readonly;
GRANT USAGE ON SCHEMA public TO mcp_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO mcp_readonly;
ALTER ROLE mcp_readonly BYPASSRLS;  -- For Supabase with RLS

-- Read-Write Role
CREATE ROLE mcp_readwrite LOGIN PASSWORD 'your-readwrite-password';
GRANT CONNECT ON DATABASE postgres TO mcp_readwrite;
GRANT USAGE ON SCHEMA public TO mcp_readwrite;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO mcp_readwrite;
GRANT USAGE, UPDATE ON ALL SEQUENCES IN SCHEMA public TO mcp_readwrite;
ALTER ROLE mcp_readwrite BYPASSRLS;  -- For Supabase with RLS
```

**Update your .env file with BOTH connections:**

```bash
# Read-Only Connection (safe, default)
CONN_prod_ro_HOST=your-supabase-host.supabase.co
CONN_prod_ro_DBNAME=postgres
CONN_prod_ro_USER=mcp_readonly
CONN_prod_ro_PASSWORD=$READONLY_PASS
CONN_prod_ro_SSLMODE=require

# Read-Write Connection (for testing writes)
CONN_prod_rw_HOST=your-supabase-host.supabase.co
CONN_prod_rw_DBNAME=postgres
CONN_prod_rw_USER=mcp_readwrite
CONN_prod_rw_PASSWORD=$READWRITE_PASS
CONN_prod_rw_SSLMODE=require
```

---

## Step 4: Start Server (1 minute)

```bash
# Build and start
docker compose up -d

# Check logs
docker compose logs -f

# Test health (in another terminal)
curl http://localhost:8799/healthz
```

**Expected response:**
```json
{
  "ok": true,
  "time": 1704096000,
  "server": "supabase-postgres-mcp",
  "connections": 2,
  "connection_names": ["prod_ro", "prod_rw"]
}
```

If you see BOTH connection names (prod_ro and prod_rw), you're ready! ✅

---

## Step 5: Connect Cursor (1 minute)

### macOS/Linux:

```bash
# Create Cursor config directory
mkdir -p ~/.cursor

# Create config file
cat > ~/.cursor/mcp.json << 'EOF'
{
  "mcpServers": {
    "postgres": {
      "url": "http://localhost:8799/mcp",
      "headers": {
        "Authorization": "Bearer YOUR_MCP_TOKEN_HERE"
      }
    }
  }
}
EOF

# Replace YOUR_MCP_TOKEN_HERE with your actual token
nano ~/.cursor/mcp.json
```

### Windows:

```powershell
# Create Cursor config directory
mkdir $env:USERPROFILE\.cursor -Force

# Create and edit config file
notepad $env:USERPROFILE\.cursor\mcp.json
```

Paste this and replace `YOUR_MCP_TOKEN_HERE`:

```json
{
  "mcpServers": {
    "postgres": {
      "url": "http://localhost:8799/mcp",
      "headers": {
        "Authorization": "Bearer YOUR_MCP_TOKEN_HERE"
      }
    }
  }
}
```

### Reload Cursor:

1. Open Command Palette: `Cmd/Ctrl + Shift + P`
2. Type: `Developer: Reload Window`
3. Check MCP settings - should show "postgres" as **Connected** ✅

---

## Step 6: Test Both Connections! (1 minute)

Open Cursor chat and test BOTH connections:

### Test Read-Only Connection (prod_ro):

```
List all tables in the prod_ro database
```

```
Query prod_ro: SELECT version()
```

```
Show me the user count from prod_ro
```

### Test Read-Write Connection (prod_rw):

```
Query prod_rw: SELECT version()
```

```
Test write access on prod_rw: CREATE TABLE test_mcp (id INT, created_at TIMESTAMP DEFAULT NOW())
```

```
Query prod_rw: INSERT INTO test_mcp (id) VALUES (1), (2), (3)
```

```
Query prod_rw: SELECT * FROM test_mcp
```

```
Clean up test table on prod_rw: DROP TABLE test_mcp
```

### Verify Read-Only Protection:

Try this on prod_ro (should FAIL):

```
Query prod_ro: CREATE TABLE should_fail (id INT)
```

You should get an error - this confirms read-only protection works! ✅

**Both connections work!** 🎉

---

## Troubleshooting

### Server won't start

```bash
# Check Docker logs
docker compose logs

# Common issues:
# 1. No database connections configured -> check .env file
# 2. Port 8799 already in use -> change MCP_PORT in .env
# 3. Invalid .env syntax -> check for typos
```

### Cursor shows "Disconnected"

```bash
# 1. Verify server is running
curl http://localhost:8799/healthz

# 2. Check token matches
cat .env | grep MCP_TOKEN
cat ~/.cursor/mcp.json

# 3. Try query parameter method instead
# In ~/.cursor/mcp.json:
{
  "mcpServers": {
    "postgres": {
      "url": "http://localhost:8799/mcp?token=YOUR_TOKEN"
    }
  }
}
```

### Database connection errors

```bash
# 1. Test connection manually
psql "postgresql://mcp_readonly:password@host:5432/postgres"

# 2. Check firewall/network
telnet your-host.supabase.co 5432

# 3. Verify SSL mode
# For Supabase: use SSLMODE=require
# For local: use SSLMODE=prefer or disable
```

---

## Next Steps

Now that you're up and running:

1. **Add more connections** - Edit `.env` and add more `CONN_*` sections
2. **Explore your data** - Use Cursor to ask questions about your schema
3. **Set up your team** - Share the setup guide with teammates
4. **Read the docs** - Check [README.md](README.md) for advanced features
5. **Secure your setup** - Review [Security](#security) section in main README

---

## Common Use Cases

### Schema Discovery

```
What tables exist in the prod database?
Describe the structure of the users table
Find all tables with an 'email' column
```

### Data Analysis

```
Count users by status in the prod database
Show me the 10 most recent orders from staging
Compare user counts between prod and dev
```

### Development

```
Query dev: SELECT * FROM feature_flags WHERE enabled = true
Check if the new column exists in staging
Show me sample data from the new table
```

---

## Tips & Tricks

### Multiple Connections

You can define as many connections as you need:

```bash
CONN_prod_HOST=prod.supabase.co
CONN_prod_DBNAME=postgres
CONN_prod_USER=mcp_readonly
CONN_prod_PASSWORD=prod_pass

CONN_staging_HOST=staging.supabase.co
CONN_staging_DBNAME=postgres
CONN_staging_USER=mcp_readonly
CONN_staging_PASSWORD=staging_pass

CONN_dev_HOST=localhost
CONN_dev_PORT=54322
CONN_dev_DBNAME=postgres
CONN_dev_USER=postgres
CONN_dev_PASSWORD=postgres
```

Then in Cursor:
```
Compare user counts: prod vs staging vs dev
```

### Read-Only Safety

By default, write operations are blocked. To enable (use with caution):

```bash
ALLOW_WRITE=true
```

**Warning:** This allows INSERT, UPDATE, DELETE, etc. Only enable if you trust all MCP clients!

### Custom Port

If port 8799 is in use:

```bash
# In .env
MCP_PORT=9999

# In Cursor config
"url": "http://localhost:9999/mcp"
```

### Remote Access

To access from another machine:

```bash
# In docker-compose.yml, already configured to bind to 0.0.0.0
# Just update Cursor config:
"url": "http://192.168.1.100:8799/mcp"
```

**Security note:** Consider using VPN or SSH tunnel for remote access!

---

## Getting Help

- **Documentation**: [README.md](README.md)
- **Cursor Setup**: [CURSOR_SETUP.md](CURSOR_SETUP.md)
- **Database Setup**: [setup-readonly-role.sql](setup-readonly-role.sql)
- **Testing**: [test-server.sh](test-server.sh)

---

**Happy querying!** 🚀
