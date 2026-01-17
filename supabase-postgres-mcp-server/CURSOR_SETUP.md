# Cursor Setup Guide

This guide explains how to integrate the Supabase Postgres MCP Server with Cursor IDE.

---

## Quick Setup

### 1. Locate Cursor Configuration Directory

The Cursor MCP configuration file location depends on your operating system:

| OS | Configuration File Path |
|----|------------------------|
| **macOS** | `~/.cursor/mcp.json` |
| **Linux** | `~/.cursor/mcp.json` |
| **Windows** | `C:\Users\YourUsername\.cursor\mcp.json` |

### 2. Create/Edit Configuration File

**macOS/Linux:**

```bash
# Create directory if it doesn't exist
mkdir -p ~/.cursor

# Edit configuration
nano ~/.cursor/mcp.json
```

**Windows:**

```powershell
# Create directory if it doesn't exist
mkdir $env:USERPROFILE\.cursor -Force

# Edit configuration
notepad $env:USERPROFILE\.cursor\mcp.json
```

### 3. Add Server Configuration

Copy the contents from `cursor-config.example.json` and customize:

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

**Important:** Replace `YOUR_MCP_TOKEN_HERE` with the `MCP_TOKEN` value from your `.env` file.

### 4. Reload Cursor

1. Open Command Palette: `Cmd/Ctrl + Shift + P`
2. Type and select: `Developer: Reload Window`
3. Wait for Cursor to restart

### 5. Verify Connection

1. Open Cursor Settings
2. Navigate to MCP Servers section
3. You should see "postgres" server listed as **Connected**
4. It should show **1 tool** available: `sql.query`

---

## Configuration Options

### Option 1: Bearer Token in Headers (Recommended)

Most secure method - token is sent in HTTP headers:

```json
{
  "mcpServers": {
    "postgres": {
      "url": "http://localhost:8799/mcp",
      "headers": {
        "Authorization": "Bearer your-secret-token-here"
      }
    }
  }
}
```

### Option 2: Token in URL Query Parameter

Alternative method if headers don't work:

```json
{
  "mcpServers": {
    "postgres": {
      "url": "http://localhost:8799/mcp?token=your-secret-token-here"
    }
  }
}
```

### Option 3: Remote Server

If your MCP server is running on a different machine:

```json
{
  "mcpServers": {
    "postgres": {
      "url": "http://192.168.1.100:8799/mcp",
      "headers": {
        "Authorization": "Bearer your-secret-token-here"
      }
    }
  }
}
```

### Option 4: Multiple Named Servers

You can configure multiple MCP servers with different names:

```json
{
  "mcpServers": {
    "postgres-prod": {
      "url": "http://prod-server:8799/mcp",
      "headers": {
        "Authorization": "Bearer prod-token"
      }
    },
    "postgres-dev": {
      "url": "http://localhost:8799/mcp",
      "headers": {
        "Authorization": "Bearer dev-token"
      }
    }
  }
}
```

---

## Using the MCP Server in Cursor

Once configured, you can interact with your databases through Cursor's chat interface.

### Basic Queries

**List all tables:**
```
List all tables in the prod database
```

**Describe a table:**
```
Show me the schema for the users table in staging
```

**Query data:**
```
Query prod: SELECT * FROM orders WHERE created_at > NOW() - INTERVAL '7 days'
```

### Advanced Queries

**Compare data across databases:**
```
Compare the user count between prod and staging databases
```

**Multi-step analysis:**
```
1. Get the list of tables in the public schema on prod
2. For each table, count the number of rows
3. Show me which tables have more than 1000 rows
```

**Schema exploration:**
```
Find all tables in staging that have a column named 'email'
```

### Specifying Connections

Your MCP server supports multiple database connections. When asking Cursor to query:

- **Be specific** about which connection to use: "prod", "staging", "dev", etc.
- **Use natural language**: "Query the production database...", "Check staging for..."
- **Connection names** are defined in your `.env` file as `CONN_<name>_*`

Example conversation:

```
You: List all available database connections

Cursor: [Calls MCP server, gets connection list]
The following connections are available:
- prod
- staging
- dev

You: Query prod database: SELECT COUNT(*) FROM users

Cursor: [Executes query using connection "prod"]
```

---

## Cursor Settings (Optional)

### Enable URL Allowlist

For additional security, you can configure Cursor to only allow specific MCP URLs:

1. Open Cursor Settings (JSON)
2. Add:

```json
{
  "mcp.enabled": true,
  "mcp.allowUrls": [
    "http://localhost:8799/mcp",
    "http://192.168.1.100:8799/mcp"
  ]
}
```

---

## Troubleshooting

### Server Shows "Disconnected"

**Check 1: Server is running**
```bash
curl http://localhost:8799/healthz
```

Expected response:
```json
{
  "ok": true,
  "time": 1704096000,
  "server": "supabase-postgres-mcp",
  "connections": 3,
  "connection_names": ["dev", "prod", "staging"]
}
```

**Check 2: Token matches**

Verify the token in `~/.cursor/mcp.json` matches `MCP_TOKEN` in your server's `.env` file.

**Check 3: URL is correct**

- Must include `/mcp` path: ✅ `http://localhost:8799/mcp`
- Missing path: ❌ `http://localhost:8799`

**Check 4: Firewall**

If server is remote, ensure port 8799 is accessible:
```bash
telnet your-server-ip 8799
```

### Server Shows "Loading Tools"

**Solution 1: Wait 30 seconds**

Cursor may take a moment to connect, especially on first connection.

**Solution 2: Check Cursor logs**

1. Open Command Palette: `Cmd/Ctrl + Shift + P`
2. Run: `Developer: Show Logs`
3. Look for MCP connection errors

**Solution 3: Restart Cursor**

Completely quit and reopen Cursor (not just reload window).

**Solution 4: Test with curl**

```bash
curl -X POST http://localhost:8799/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

### "Unauthorized" Errors

**Problem:** Getting 401 errors in Cursor

**Solutions:**

1. **Token mismatch** - Verify token is correct:
   ```bash
   # On server
   cat .env | grep MCP_TOKEN

   # In Cursor config
   cat ~/.cursor/mcp.json
   ```

2. **Try query parameter method:**
   ```json
   {
     "mcpServers": {
       "postgres": {
         "url": "http://localhost:8799/mcp?token=YOUR_TOKEN"
       }
     }
   }
   ```

3. **Check for whitespace** - No spaces in token value

### "Connection Refused"

**Problem:** Cursor can't reach the server

**Solutions:**

1. **Verify server is running:**
   ```bash
   docker compose ps
   # or
   ps aux | grep server.py
   ```

2. **Check port binding:**
   ```bash
   netstat -an | grep 8799
   # or
   lsof -i :8799
   ```

3. **Test from same machine:**
   ```bash
   curl http://localhost:8799/healthz
   ```

4. **If on different machine, use IP:**
   ```json
   {
     "mcpServers": {
       "postgres": {
         "url": "http://192.168.1.100:8799/mcp",
         "headers": {
           "Authorization": "Bearer YOUR_TOKEN"
         }
       }
     }
   }
   ```

### Queries Fail

**Check server logs:**
```bash
docker compose logs -f
# or
tail -f logs/mcp-server.log
```

**Common issues:**

1. **Unknown connection** - Verify connection name exists:
   ```bash
   curl http://localhost:8799/healthz
   ```

2. **Permission denied** - Database role needs permissions

3. **Timeout** - Query too slow, add LIMIT or optimize

---

## Example Workflows

### 1. Schema Discovery

```
You: What databases are available?

Cursor: [Lists connections from healthz]

You: Show me all tables in the prod database

Cursor: [Queries information_schema.tables]

You: Describe the users table structure

Cursor: [Queries information_schema.columns]
```

### 2. Data Analysis

```
You: Query prod: SELECT status, COUNT(*) FROM orders GROUP BY status

Cursor: [Shows results]

You: Now compare with staging

Cursor: [Queries staging database]

You: Create a summary comparing both
```

### 3. Troubleshooting

```
You: Find all tables in dev that contain the word 'user'

Cursor: [Searches information_schema]

You: Show me the last 10 records from user_events

Cursor: [Queries with LIMIT]
```

---

## Security Notes

⚠️ **Important Security Considerations:**

1. **Token Protection**
   - The `mcp.json` file contains your authentication token
   - Keep this file secure and never commit to version control
   - Use file permissions to restrict access:
     ```bash
     chmod 600 ~/.cursor/mcp.json
     ```

2. **Network Security**
   - Use HTTPS/SSL in production (reverse proxy)
   - Consider VPN for remote access
   - Use firewall rules to restrict access

3. **Token Rotation**
   - Regularly rotate your `MCP_TOKEN`
   - Update both server `.env` and Cursor `mcp.json`

4. **Read-Only Mode**
   - Keep `ALLOW_WRITE=false` unless absolutely necessary
   - Write operations bypass read-only database roles

---

## Next Steps

After successful setup:

1. ✅ Try basic queries to verify connection
2. ✅ Explore your database schema
3. ✅ Set up additional connections if needed
4. ✅ Configure team members with same setup
5. ✅ Review security best practices in main README

For more detailed information, see the main [README.md](README.md).
