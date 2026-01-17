# Supabase Postgres MCP Server

> A production-ready **Model Context Protocol (MCP)** server that provides secure, multi-database SQL access to **Supabase** and **PostgreSQL** instances. Built for AI coding assistants like **Cursor**, **Claude Desktop**, and other MCP clients.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/downloads/)
[![Docker](https://img.shields.io/badge/docker-ready-brightgreen.svg)](https://www.docker.com/)

---

## Features

✨ **Multi-Database Support** - Connect to multiple named Supabase/PostgreSQL databases simultaneously
🔒 **Security First** - Read-only by default, bearer token authentication, query timeouts
📊 **Smart Limits** - Automatic row limits, query timeouts, and safe query execution
🚀 **Production Ready** - Structured JSON logging, health checks, Docker support
🔌 **MCP Compatible** - Works with Cursor, Claude Desktop, and other MCP clients
⚡ **Real-time** - SSE (Server-Sent Events) for instant query results
🐳 **Docker Ready** - One-command deployment with docker-compose

---

## Table of Contents

- [Quick Start](#quick-start)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Cursor Integration](#cursor-integration)
- [Security](#security)
- [API Reference](#api-reference)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## Quick Start

### 1. Clone and Configure

```bash
# Clone or copy the server files
cd supabase-postgres-mcp-server

# Copy environment template
cp .env.example .env

# Edit .env with your database credentials
nano .env
```

### 2. Run with Docker

```bash
# Build and start
docker compose up -d

# Check logs
docker compose logs -f

# Test health
curl http://localhost:8799/healthz
```

### 3. Connect from Cursor

Create or edit `~/.cursor/mcp.json`:

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

Reload Cursor and start querying your databases!

---

## Installation

### Prerequisites

- **Docker** and **docker-compose** (recommended)
- OR **Python 3.11+** for local development
- Access to your Supabase/PostgreSQL databases
- A read-only database role (see [Security Setup](#database-security-setup))

### Option 1: Docker (Recommended)

```bash
# 1. Configure environment
cp .env.example .env
# Edit .env with your settings

# 2. Build and run
docker compose up -d

# 3. Verify
docker compose logs -f
curl http://localhost:8799/healthz
```

### Option 2: Local Development

```bash
# 1. Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# 2. Install dependencies
pip install -r requirements.txt

# 3. Configure environment
cp .env.example .env
# Edit .env with your settings

# 4. Run server
python server.py
```

---

## Configuration

### Environment Variables

The server is configured entirely through environment variables defined in `.env`:

#### Server Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `MCP_SERVER_NAME` | `supabase-postgres-mcp` | Server identifier |
| `MCP_PORT` | `8799` | HTTP server port |
| `MCP_PATH` | `/mcp` | MCP endpoint path |
| `MCP_TOKEN` | *(required)* | Authentication token |

#### Query Limits

| Variable | Default | Description |
|----------|---------|-------------|
| `ROW_LIMIT` | `5000` | Max rows per query |
| `QUERY_TIMEOUT_MS` | `15000` | Query timeout (ms) |
| `ALLOW_WRITE` | `false` | Enable write operations |

#### Logging

| Variable | Default | Description |
|----------|---------|-------------|
| `LOG_LEVEL` | `INFO` | Log level (DEBUG, INFO, WARNING, ERROR) |
| `LOG_FORMAT` | `json` | Log format (json or simple) |

### Database Connections

Define multiple database connections using the pattern:

```bash
CONN_<name>_HOST=your-host.supabase.co
CONN_<name>_PORT=5432
CONN_<name>_DBNAME=postgres
CONN_<name>_USER=mcp_readonly
CONN_<name>_PASSWORD=secure_password
CONN_<name>_SSLMODE=require
```

#### Example: Multiple Connections

```bash
# Production database
CONN_prod_HOST=prod.supabase.co
CONN_prod_DBNAME=postgres
CONN_prod_USER=mcp_readonly
CONN_prod_PASSWORD=prod_password
CONN_prod_SSLMODE=require

# Staging database
CONN_staging_HOST=staging.supabase.co
CONN_staging_DBNAME=postgres
CONN_staging_USER=mcp_readonly
CONN_staging_PASSWORD=staging_password
CONN_staging_SSLMODE=require

# Local development
CONN_dev_HOST=localhost
CONN_dev_PORT=54322
CONN_dev_DBNAME=postgres
CONN_dev_USER=postgres
CONN_dev_PASSWORD=postgres
CONN_dev_SSLMODE=disable
```

### SSL Mode Options

| Mode | Description | Use Case |
|------|-------------|----------|
| `disable` | No SSL encryption | Local development only |
| `prefer` | Try SSL, fall back to plain | Development |
| `require` | Require SSL (recommended) | **Production/Supabase** |
| `verify-ca` | Verify certificate authority | High security |
| `verify-full` | Verify CA and hostname | Maximum security |

---

## Usage

### Basic Query Examples

Once configured, your MCP client (Cursor, Claude Desktop, etc.) can query your databases:

#### Query a Specific Connection

```
Query the prod database: SELECT * FROM users LIMIT 10
```

#### Compare Data Across Databases

```
Get user count from prod and staging databases and compare
```

#### Schema Exploration

```
List all tables in the public schema on the staging database
```

### SQL Tool Schema

The server exposes one MCP tool: `sql.query`

**Parameters:**
- `connection` (required): Name of the database connection (e.g., "prod", "staging")
- `sql` (required): SQL query to execute
- `params` (optional): Array of parameters for parameterized queries

**Example JSON-RPC Call:**

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "sql.query",
    "arguments": {
      "connection": "prod",
      "sql": "SELECT * FROM users WHERE status = $1 LIMIT 20",
      "params": ["active"]
    }
  }
}
```

### Useful SQL Queries

#### Check Connection Info

```sql
SELECT current_database() as db,
       current_user as user,
       version() as version;
```

#### List All Schemas

```sql
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name NOT IN ('pg_catalog', 'information_schema')
ORDER BY schema_name;
```

#### List Tables in Schema

```sql
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
```

#### Describe Table Structure

```sql
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'your_table'
ORDER BY ordinal_position;
```

#### Search for Tables/Columns

```sql
SELECT table_schema, table_name, column_name
FROM information_schema.columns
WHERE column_name ILIKE '%email%'
ORDER BY table_schema, table_name;
```

---

## Cursor Integration

### Step 1: Configure MCP Server

Create or edit your Cursor MCP configuration file:

**macOS/Linux:**
```bash
mkdir -p ~/.cursor
nano ~/.cursor/mcp.json
```

**Windows:**
```bash
mkdir %USERPROFILE%\.cursor
notepad %USERPROFILE%\.cursor\mcp.json
```

### Step 2: Add Server Configuration

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

**Alternative: Token in URL**

```json
{
  "mcpServers": {
    "postgres": {
      "url": "http://localhost:8799/mcp?token=YOUR_MCP_TOKEN_HERE"
    }
  }
}
```

### Step 3: Reload Cursor

1. Open Command Palette (`Cmd/Ctrl + Shift + P`)
2. Run: `Developer: Reload Window`
3. Check MCP servers list - should show "Connected" with 1 tool

### Step 4: Start Querying

In Cursor chat, try:

```
List all tables in the prod database
```

```
Show me the schema for the users table in staging
```

```
Query dev database: SELECT COUNT(*) FROM orders WHERE created_at > NOW() - INTERVAL '7 days'
```

---

## Security

### Database Security Setup

Create a dedicated read-only role for the MCP server:

```sql
-- 1. Create read-only role
CREATE ROLE mcp_readonly LOGIN PASSWORD 'your_secure_password_here';

-- 2. Grant connection
GRANT CONNECT ON DATABASE postgres TO mcp_readonly;

-- 3. Grant schema access
GRANT USAGE ON SCHEMA public TO mcp_readonly;

-- 4. Grant read access to all tables
GRANT SELECT ON ALL TABLES IN SCHEMA public TO mcp_readonly;

-- 5. Grant read access to future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT ON TABLES TO mcp_readonly;

-- 6. For multiple schemas, repeat steps 3-5 for each schema
-- Example for 'app' schema:
GRANT USAGE ON SCHEMA app TO mcp_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA app TO mcp_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA app
GRANT SELECT ON TABLES TO mcp_readonly;
```

### Supabase-Specific Setup

For Supabase databases with Row Level Security (RLS):

```sql
-- Option 1: Grant BYPASSRLS (use with caution)
ALTER ROLE mcp_readonly BYPASSRLS;

-- Option 2: Create RLS policies for the mcp_readonly role
-- (Recommended for fine-grained control)
CREATE POLICY mcp_readonly_policy ON your_table
FOR SELECT TO mcp_readonly
USING (true);
```

### Security Best Practices

1. ✅ **Use Read-Only Roles** - Never give write permissions unless absolutely necessary
2. ✅ **Strong Tokens** - Generate with `openssl rand -base64 32`
3. ✅ **Environment Isolation** - Keep `.env` out of version control
4. ✅ **SSL Encryption** - Use `SSLMODE=require` for production
5. ✅ **IP Whitelisting** - Restrict database access to known IPs
6. ✅ **Regular Rotation** - Rotate `MCP_TOKEN` periodically
7. ✅ **Network Isolation** - Run behind VPN or use private networks
8. ✅ **Audit Logs** - Monitor query patterns and access

### Authentication Methods

The server supports three authentication methods (checked in order):

1. **Authorization Header** (recommended)
   ```bash
   Authorization: Bearer YOUR_TOKEN
   ```

2. **Custom Header**
   ```bash
   X-MCP-Token: YOUR_TOKEN
   ```

3. **Query Parameter**
   ```bash
   http://localhost:8799/mcp?token=YOUR_TOKEN
   ```

---

## API Reference

### HTTP Endpoints

#### `GET /healthz`

Health check endpoint.

**Response:**
```json
{
  "ok": true,
  "time": 1704096000,
  "server": "supabase-postgres-mcp",
  "connections": 3,
  "connection_names": ["dev", "prod", "staging"]
}
```

#### `GET /mcp`

SSE (Server-Sent Events) stream for real-time MCP messages.

**Headers:**
- `Authorization: Bearer <token>` (or use `?token=<token>`)

**Response:** Event stream

#### `POST /mcp`

Main MCP endpoint for JSON-RPC 2.0 requests.

**Headers:**
- `Content-Type: application/json`
- `Authorization: Bearer <token>` (or use `?token=<token>`)

**Supported Methods:**
- `initialize` / `server/initialize`
- `server/info`
- `tools/list`
- `tools/call`
- `prompts/list`
- `resources/list`

---

## Troubleshooting

### Server Won't Start

**Problem:** `No database connections configured`

**Solution:** Check your `.env` file has at least one complete `CONN_*` configuration:

```bash
CONN_prod_HOST=your-host.supabase.co
CONN_prod_DBNAME=postgres
CONN_prod_USER=mcp_readonly
CONN_prod_PASSWORD=your_password
```

---

### Connection Refused

**Problem:** `Failed to connect to database: connection refused`

**Solution:**
1. Verify database host is accessible: `telnet your-host.supabase.co 5432`
2. Check firewall rules
3. Verify SSL mode is correct (use `require` for Supabase)
4. Check database credentials

---

### Authentication Failed

**Problem:** `401 Unauthorized`

**Solution:**
1. Verify `MCP_TOKEN` in `.env` matches token in Cursor config
2. Check token is passed correctly (header or query param)
3. Try query param method: `?token=YOUR_TOKEN`

---

### Query Timeout

**Problem:** `Query exceeded timeout of 15000ms`

**Solution:**
1. Optimize your SQL query (add indexes, reduce joins)
2. Increase timeout: `QUERY_TIMEOUT_MS=30000` in `.env`
3. Add explicit `LIMIT` to your query

---

### Permission Denied

**Problem:** `Insufficient privileges: permission denied for table X`

**Solution:**
1. Grant SELECT on the table:
   ```sql
   GRANT SELECT ON TABLE your_table TO mcp_readonly;
   ```
2. For Supabase with RLS:
   ```sql
   ALTER ROLE mcp_readonly BYPASSRLS;
   ```

---

### Write Operation Blocked

**Problem:** `Write operations are disabled`

**Solution:**
1. If you need write access, set in `.env`:
   ```bash
   ALLOW_WRITE=true
   ```
2. Restart the server
3. **Warning:** Only enable if you trust all MCP clients!

---

### Cursor Shows "Loading Tools"

**Problem:** MCP server stuck in "Loading" state

**Solution:**
1. Check server is running: `curl http://localhost:8799/healthz`
2. Verify URL in Cursor config includes `/mcp` path
3. Check Cursor logs for connection errors
4. Try reloading Cursor window
5. Verify authentication token is correct

---

## Docker Commands

### Build and Run

```bash
# Build and start in background
docker compose up -d --build

# View logs
docker compose logs -f

# Stop server
docker compose down

# Restart server
docker compose restart

# Remove everything (including volumes)
docker compose down -v
```

### Debugging

```bash
# Check server status
docker compose ps

# Enter container shell
docker compose exec mcp-server sh

# View real-time logs
docker compose logs -f --tail=100

# Check health
docker compose exec mcp-server curl http://localhost:8799/healthz
```

---

## Development

### Running Locally

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run with simple logging
LOG_FORMAT=simple python server.py
```

### Testing

```bash
# Test health endpoint
curl http://localhost:8799/healthz

# Test MCP initialize
curl -X POST http://localhost:8799/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'

# Test tools/list
curl -X POST http://localhost:8799/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'

# Test SQL query
curl -X POST http://localhost:8799/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "jsonrpc":"2.0",
    "id":3,
    "method":"tools/call",
    "params":{
      "name":"sql.query",
      "arguments":{
        "connection":"prod",
        "sql":"SELECT 1 as test"
      }
    }
  }'
```

---

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

### Development Setup

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

## License

MIT License - see LICENSE file for details

---

## Acknowledgments

- Built with [FastAPI](https://fastapi.tiangolo.com/)
- PostgreSQL adapter: [psycopg3](https://www.psycopg.org/)
- MCP Protocol: [Model Context Protocol](https://modelcontextprotocol.io/)

---

## Support

- 📖 Documentation: [This README]
- 🐛 Issues: [GitHub Issues](https://github.com/yourusername/supabase-postgres-mcp-server/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/yourusername/supabase-postgres-mcp-server/discussions)

---

**Made with ❤️ for the MCP community**
