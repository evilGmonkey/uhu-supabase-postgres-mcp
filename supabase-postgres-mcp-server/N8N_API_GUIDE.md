# n8n REST API Guide

This document describes the simplified REST API endpoints added specifically for n8n integration and other tools that don't need the full MCP protocol complexity.

**Note:** All existing MCP endpoints remain fully functional. These new endpoints are additions, not replacements.

---

## Authentication

All API endpoints require authentication using one of these methods:

### 1. Bearer Token (Recommended)
```http
Authorization: Bearer YOUR_MCP_TOKEN
```

### 2. Custom Header
```http
X-MCP-Token: YOUR_MCP_TOKEN
```

### 3. Query Parameter
```http
GET /api/connections?token=YOUR_MCP_TOKEN
```

---

## Endpoints Overview

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/connections` | GET | List available database connections |
| `/api/query` | POST | Execute SQL query |
| `/api/schema` | POST | Get table schema information |
| `/healthz` | GET | Health check (existing) |

---

## 1. List Available Connections

Get a list of all configured database connections.

### Request

```http
GET /api/connections
Authorization: Bearer YOUR_MCP_TOKEN
```

### Response (Success - 200)

```json
{
  "ok": true,
  "connections": [
    {
      "name": "prod_ro",
      "description": "Database connection: prod_ro"
    },
    {
      "name": "staging_ro",
      "description": "Database connection: staging_ro"
    },
    {
      "name": "dev",
      "description": "Database connection: dev"
    }
  ],
  "count": 3
}
```

### Response (Unauthorized - 401)

```json
{
  "detail": "Unauthorized"
}
```

### n8n HTTP Request Node Configuration

```json
{
  "method": "GET",
  "url": "http://localhost:8799/api/connections",
  "authentication": "genericCredentialType",
  "genericAuthType": "httpHeaderAuth",
  "httpHeaderAuth": {
    "name": "Authorization",
    "value": "Bearer YOUR_MCP_TOKEN"
  }
}
```

---

## 2. Execute SQL Query

Execute a SQL query against a named database connection.

### Request

```http
POST /api/query
Authorization: Bearer YOUR_MCP_TOKEN
Content-Type: application/json

{
  "connection": "prod_ro",
  "sql": "SELECT id, name, status FROM vehicles WHERE status = $1 LIMIT 10",
  "params": ["active"]
}
```

### Request Body Parameters

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `connection` | string | Yes | Name of the database connection (from `/api/connections`) |
| `sql` | string | Yes | SQL query to execute |
| `params` | array | No | Optional query parameters for parameterized queries ($1, $2, etc.) |

### Response (Success - 200)

```json
{
  "ok": true,
  "rows": [
    {
      "id": 1,
      "name": "Vehicle Alpha",
      "status": "active"
    },
    {
      "id": 2,
      "name": "Vehicle Beta",
      "status": "active"
    }
  ],
  "row_count": 2,
  "connection": "prod_ro",
  "execution_time_ms": 45
}
```

### Response (Error - 400/403/404/408/500/503)

```json
{
  "ok": false,
  "error": "Unknown connection: 'prod_rw'. Available: prod_ro, staging_ro, dev",
  "error_code": 404
}
```

### Common Error Codes

| Code | Meaning | Common Causes |
|------|---------|---------------|
| 400 | Bad Request | Missing fields, invalid JSON, SQL syntax error |
| 403 | Forbidden | Write operation attempted in read-only mode |
| 404 | Not Found | Unknown connection name |
| 408 | Timeout | Query exceeded timeout (15s default) |
| 503 | Service Unavailable | Database connection failed |
| 500 | Internal Error | Unexpected server error |

### Security Features

- **Read-only by default**: INSERT, UPDATE, DELETE, DROP, ALTER, CREATE, GRANT, REVOKE, TRUNCATE are blocked unless `ALLOW_WRITE=true`
- **Automatic LIMIT**: Queries without LIMIT get `LIMIT 5000` added automatically
- **Query timeout**: Queries are killed after 15 seconds (configurable via `QUERY_TIMEOUT_MS`)
- **Parameterized queries**: Use `$1, $2, etc.` to prevent SQL injection

### n8n HTTP Request Node Configuration

```json
{
  "method": "POST",
  "url": "http://localhost:8799/api/query",
  "authentication": "genericCredentialType",
  "genericAuthType": "httpHeaderAuth",
  "httpHeaderAuth": {
    "name": "Authorization",
    "value": "Bearer YOUR_MCP_TOKEN"
  },
  "bodyParameters": {
    "connection": "prod_ro",
    "sql": "SELECT COUNT(*) as total FROM vehicles",
    "params": []
  }
}
```

---

## 3. Get Schema Information

Retrieve database schema information to help AI agents understand table structures.

### Request - List All Tables

```http
POST /api/schema
Authorization: Bearer YOUR_MCP_TOKEN
Content-Type: application/json

{
  "connection": "prod_ro"
}
```

### Response - All Tables (200)

```json
{
  "ok": true,
  "connection": "prod_ro",
  "tables": [
    {
      "table_name": "vehicles",
      "table_schema": "public"
    },
    {
      "table_name": "users",
      "table_schema": "public"
    },
    {
      "table_name": "orders",
      "table_schema": "public"
    }
  ]
}
```

### Request - Specific Table Details

```http
POST /api/schema
Authorization: Bearer YOUR_MCP_TOKEN
Content-Type: application/json

{
  "connection": "prod_ro",
  "table": "vehicles"
}
```

### Response - Table Columns (200)

```json
{
  "ok": true,
  "connection": "prod_ro",
  "table": "vehicles",
  "columns": [
    {
      "column_name": "id",
      "data_type": "integer",
      "is_nullable": "NO",
      "column_default": "nextval('vehicles_id_seq'::regclass)"
    },
    {
      "column_name": "name",
      "data_type": "character varying",
      "is_nullable": "NO",
      "column_default": null
    },
    {
      "column_name": "status",
      "data_type": "character varying",
      "is_nullable": "YES",
      "column_default": "'active'::character varying"
    },
    {
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "is_nullable": "YES",
      "column_default": "now()"
    }
  ]
}
```

### Request Body Parameters

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `connection` | string | Yes | Name of the database connection |
| `table` | string | No | Specific table name. If omitted, returns all tables |

### n8n HTTP Request Node Configuration

```json
{
  "method": "POST",
  "url": "http://localhost:8799/api/schema",
  "authentication": "genericCredentialType",
  "genericAuthType": "httpHeaderAuth",
  "httpHeaderAuth": {
    "name": "Authorization",
    "value": "Bearer YOUR_MCP_TOKEN"
  },
  "bodyParameters": {
    "connection": "prod_ro",
    "table": "vehicles"
  }
}
```

---

## Complete n8n Workflow Example

Here's a complete example of an n8n workflow that uses these APIs:

### Scenario: Answer "How many vehicles are there?"

```
1. [Webhook Trigger] - Receives user question
   ↓
2. [HTTP Request: List Connections] - GET /api/connections
   ↓
3. [HTTP Request: Get Schema] - POST /api/schema (connection: prod_ro)
   ↓
4. [AI Agent Node] - Uses schema to craft SQL query
   ↓
5. [HTTP Request: Execute Query] - POST /api/query
   {
     "connection": "prod_ro",
     "sql": "SELECT COUNT(*) as total FROM vehicles"
   }
   ↓
6. [AI Agent Node] - Formats response: "There are 150 vehicles"
   ↓
7. [Respond to Webhook] - Returns answer to user
```

### Sample n8n Node Configurations

#### Node 1: List Connections
```json
{
  "name": "Get Available Connections",
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "http://localhost:8799/api/connections",
    "method": "GET",
    "authentication": "genericCredentialType",
    "genericAuthType": "httpHeaderAuth",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "Authorization",
          "value": "Bearer {{ $env.MCP_TOKEN }}"
        }
      ]
    }
  }
}
```

#### Node 2: Get Table Schema
```json
{
  "name": "Get Vehicles Schema",
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "http://localhost:8799/api/schema",
    "method": "POST",
    "authentication": "genericCredentialType",
    "genericAuthType": "httpHeaderAuth",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "Authorization",
          "value": "Bearer {{ $env.MCP_TOKEN }}"
        }
      ]
    },
    "sendBody": true,
    "bodyParameters": {
      "parameters": [
        {
          "name": "connection",
          "value": "prod_ro"
        },
        {
          "name": "table",
          "value": "vehicles"
        }
      ]
    }
  }
}
```

#### Node 3: Execute Query
```json
{
  "name": "Count Vehicles",
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "http://localhost:8799/api/query",
    "method": "POST",
    "authentication": "genericCredentialType",
    "genericAuthType": "httpHeaderAuth",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "Authorization",
          "value": "Bearer {{ $env.MCP_TOKEN }}"
        }
      ]
    },
    "sendBody": true,
    "bodyParameters": {
      "parameters": [
        {
          "name": "connection",
          "value": "prod_ro"
        },
        {
          "name": "sql",
          "value": "SELECT COUNT(*) as total FROM vehicles"
        }
      ]
    }
  }
}
```

---

## AI Agent System Prompt Template

Use this template to help your AI agents understand how to use the database APIs:

```
You are a database query assistant with access to the following tools:

1. **List Connections** - GET /api/connections
   Use this to discover available database connections.

2. **Get Schema** - POST /api/schema
   Use this to learn about table structures before writing queries.
   Example: {"connection": "prod_ro", "table": "vehicles"}

3. **Execute Query** - POST /api/query
   Use this to execute SQL queries.
   Example: {"connection": "prod_ro", "sql": "SELECT COUNT(*) FROM vehicles"}

**Available Connections:** prod_ro, staging_ro, dev

**Known Tables and Schemas:**

### vehicles table
- id (integer, NOT NULL)
- name (varchar, NOT NULL)
- status (varchar, default: 'active')
- created_at (timestamp)

### users table
- id (integer, NOT NULL)
- email (varchar, NOT NULL)
- name (varchar)
- created_at (timestamp)

**Important Rules:**
1. Always use parameterized queries with $1, $2, etc. for user input
2. Queries are read-only - no INSERT/UPDATE/DELETE
3. Queries auto-limited to 5000 rows if no LIMIT specified
4. Always use the appropriate connection (prod_ro for production data)

**When user asks a question:**
1. Identify which table(s) are relevant
2. Craft appropriate SQL query
3. Execute via /api/query
4. Format results in natural language
```

---

## Specialized Tool Example

Here's how to create a specialized "Vehicle Tool" that knows about the vehicles table:

### Vehicle Tool System Prompt

```
You are the Vehicle Database Tool. You specialize in answering questions about vehicles.

**Your Database Connection:** prod_ro

**Your Table Schema:**
Table: vehicles
- id (integer) - Primary key
- name (varchar) - Vehicle name
- status (varchar) - Status: 'active', 'inactive', 'maintenance'
- make (varchar) - Vehicle manufacturer
- model (varchar) - Vehicle model
- year (integer) - Year of manufacture
- license_plate (varchar) - License plate number
- created_at (timestamp) - When record was created

**Your Capabilities:**
- Count vehicles
- List vehicles by status
- Search vehicles by name, make, or model
- Get vehicle details by ID or license plate

**Example Queries You Can Answer:**
- "How many vehicles are there?" → SELECT COUNT(*) FROM vehicles
- "Show active vehicles" → SELECT * FROM vehicles WHERE status = 'active'
- "Find vehicles by Tesla" → SELECT * FROM vehicles WHERE make = 'Tesla'

**API Endpoint:** POST http://localhost:8799/api/query

**Always:**
1. Use connection: "prod_ro"
2. Craft appropriate SQL for the question
3. Return results in natural language
```

---

## Testing the APIs

### Using cURL

```bash
# 1. List connections
curl -X GET http://localhost:8799/api/connections \
  -H "Authorization: Bearer YOUR_TOKEN"

# 2. Get all tables
curl -X POST http://localhost:8799/api/schema \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"connection": "prod_ro"}'

# 3. Get specific table schema
curl -X POST http://localhost:8799/api/schema \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"connection": "prod_ro", "table": "vehicles"}'

# 4. Execute query
curl -X POST http://localhost:8799/api/query \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"connection": "prod_ro", "sql": "SELECT COUNT(*) FROM vehicles"}'

# 5. Parameterized query
curl -X POST http://localhost:8799/api/query \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"connection": "prod_ro", "sql": "SELECT * FROM vehicles WHERE status = $1", "params": ["active"]}'
```

---

## Comparison: MCP vs REST APIs

| Feature | MCP Endpoints | REST API Endpoints |
|---------|---------------|-------------------|
| **Path** | `/mcp` | `/api/*` |
| **Protocol** | JSON-RPC 2.0 + SSE | Simple REST |
| **Best For** | Cursor, Claude Desktop | n8n, custom tools |
| **Complexity** | Higher | Lower |
| **Standards** | MCP protocol | Standard HTTP |
| **Query Tool** | `tools/call` with `sql.query` | `/api/query` |
| **Schema Info** | Not available | `/api/schema` |
| **Connection List** | Via `tools/list` description | `/api/connections` |

**Both sets of endpoints:**
- Use same authentication (MCP_TOKEN)
- Share same security features (read-only, timeouts, limits)
- Access same database connections
- Use same underlying SQL execution engine

---

## Troubleshooting

### Connection Refused
```bash
# Check if server is running
curl http://localhost:8799/healthz
```

### Unauthorized (401)
- Verify MCP_TOKEN is set in .env
- Check Authorization header format: "Bearer TOKEN"
- Ensure token matches exactly (no extra spaces)

### Unknown Connection (404)
```bash
# List available connections
curl -X GET http://localhost:8799/api/connections \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Write Operations Blocked (403)
- Server is in read-only mode (default)
- Set `ALLOW_WRITE=true` in .env if you need write access
- Restart server after changing .env

### Query Timeout (408)
- Query took longer than QUERY_TIMEOUT_MS (default: 15000ms)
- Optimize query or increase timeout in .env
- Check database performance

---

## Security Best Practices

1. **Use Read-Only Connections**
   - Create separate database roles: `mcp_readonly` and `mcp_readwrite`
   - Use `_ro` suffix for read-only connections
   - Only use write connections when absolutely necessary

2. **Environment-Specific Tokens**
   - Use different MCP_TOKEN for each environment
   - Rotate tokens regularly
   - Never commit tokens to version control

3. **Parameterized Queries**
   - Always use `$1, $2` parameters for user input
   - Never concatenate user input into SQL strings
   - Prevents SQL injection attacks

4. **Connection Naming**
   - Use descriptive names: `prod_ro`, `staging_rw`
   - Include permission level in name
   - Makes it clear what each connection can do

5. **Network Security**
   - Run server behind firewall
   - Use HTTPS in production
   - Restrict access to trusted networks only

---

## Next Steps

1. **Set up your .env file** with database connections
2. **Start the server**: `docker compose up -d`
3. **Test the APIs** using the cURL examples above
4. **Build your n8n workflow** using the node configurations
5. **Create specialized AI tools** with domain-specific system prompts

For more information, see:
- [README.md](README.md) - Complete server documentation
- [QUICKSTART.md](QUICKSTART.md) - 5-minute setup guide
- [CURSOR_SETUP.md](CURSOR_SETUP.md) - Cursor IDE integration
