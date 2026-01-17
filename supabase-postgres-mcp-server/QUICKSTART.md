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

```bash
# MCP_TOKEN is already set from step 2 above
MCP_TOKEN=<generated-token-from-step-2>

# Configure at least one database connection
CONN_prod_HOST=your-supabase-host.supabase.co
CONN_prod_DBNAME=postgres
CONN_prod_USER=mcp_readonly
CONN_prod_PASSWORD=your-database-password
CONN_prod_SSLMODE=require
```

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

## Step 3: Setup Database Role (1 minute)

Run this SQL on your database to create a read-only role:

```sql
-- Option 1: Run the provided script
-- psql "postgresql://postgres:PASSWORD@HOST:PORT/DATABASE" -f setup-readonly-role.sql

-- Option 2: Quick manual setup
CREATE ROLE mcp_readonly LOGIN PASSWORD 'your-password-here';
GRANT CONNECT ON DATABASE postgres TO mcp_readonly;
GRANT USAGE ON SCHEMA public TO mcp_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO mcp_readonly;

-- For Supabase with RLS (Row Level Security)
ALTER ROLE mcp_readonly BYPASSRLS;
```

**Use the same password in your .env file!**

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
  "connections": 1,
  "connection_names": ["prod"]
}
```

If you see your connection name(s), you're ready! ✅

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

## Step 6: Test It Out! (30 seconds)

Open Cursor chat and try:

```
List all tables in the prod database
```

```
Show me the schema for the users table
```

```
Query prod: SELECT version()
```

**It works!** 🎉

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
