# n8n Integration Changelog

## Version 1.1.0 - n8n REST API Integration

**Date:** 2026-01-18

### Summary

Added simplified REST API endpoints specifically designed for n8n AI agents and automation workflows, while maintaining full backward compatibility with existing MCP protocol endpoints.

---

## What's New

### 🎉 New REST API Endpoints

#### 1. `/api/connections` (GET)
List all available database connections.

**Purpose:** Allows n8n workflows to discover which databases are available.

**Response:**
```json
{
  "ok": true,
  "connections": [
    {"name": "prod_ro", "description": "Database connection: prod_ro"},
    {"name": "staging_ro", "description": "Database connection: staging_ro"}
  ],
  "count": 2
}
```

#### 2. `/api/query` (POST)
Execute SQL queries with simple request/response format.

**Purpose:** Main endpoint for n8n AI agents to run database queries.

**Request:**
```json
{
  "connection": "prod_ro",
  "sql": "SELECT COUNT(*) FROM vehicles",
  "params": []  // optional
}
```

**Response:**
```json
{
  "ok": true,
  "rows": [{"count": 150}],
  "row_count": 1,
  "connection": "prod_ro",
  "execution_time_ms": 45
}
```

#### 3. `/api/schema` (POST)
Get database schema information for AI agents to understand table structures.

**Purpose:** Enables AI agents to learn about tables and columns before crafting queries.

**Request (list all tables):**
```json
{
  "connection": "prod_ro"
}
```

**Request (specific table):**
```json
{
  "connection": "prod_ro",
  "table": "vehicles"
}
```

**Response:**
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
    }
  ]
}
```

---

## Changes Made

### Modified Files

#### 1. `server.py` (Lines 390-600+)
- **Added:** Three new REST API route handlers
- **Added:** Comprehensive error handling for REST endpoints
- **Added:** Detailed docstrings for each endpoint
- **Preserved:** All existing MCP protocol functionality
- **Impact:** Zero breaking changes - all existing code still works

**Key Implementation Details:**
- Same authentication mechanism (uses `auth_ok()`)
- Same security features (uses `is_readonly()` and `run_sql()`)
- Same query safety (timeouts, limits, parameterization)
- Consistent logging patterns
- Standard HTTP status codes

### New Files

#### 2. `N8N_API_GUIDE.md`
Comprehensive guide for n8n integration (275+ lines):
- Complete API reference with examples
- n8n HTTP Request node configurations
- AI agent system prompt templates
- Specialized tool examples
- Testing with cURL
- Security best practices
- Troubleshooting guide

#### 3. `test-n8n-api.sh`
Test script for new REST API endpoints:
- Tests all three new endpoints
- Validates error handling
- Confirms backward compatibility
- Tests authentication
- Tests parameterized queries

#### 4. `CHANGELOG_N8N.md`
This file - documents all changes for the n8n integration.

### Updated Documentation

#### 5. `README.md` (server directory)
- Added n8n Integration section
- Added feature badge for n8n
- Updated table of contents
- Added quick examples
- Linked to N8N_API_GUIDE.md

#### 6. `README.md` (root directory)
- Added n8n feature highlight
- Updated documentation links
- Added N8N_API_GUIDE.md reference

---

## Backward Compatibility

### ✅ 100% Backward Compatible

**All existing functionality preserved:**
- ✅ MCP protocol endpoints (`/mcp`) - unchanged
- ✅ Health check endpoint (`/healthz`) - unchanged
- ✅ Authentication mechanism - unchanged
- ✅ Security features - unchanged
- ✅ Database connection management - unchanged
- ✅ Query execution engine - unchanged
- ✅ Logging system - unchanged

**Testing:**
- All existing MCP clients (Cursor, Claude Desktop) continue to work
- No configuration changes required for existing users
- Test script verifies both old and new endpoints

---

## Architecture

### Dual API Design

```
                    ┌─────────────────────────────────┐
                    │   MCP Server (server.py)        │
                    │                                 │
                    │  Shared Core:                   │
                    │  - auth_ok()                    │
                    │  - is_readonly()                │
                    │  - run_sql()                    │
                    │  - CONNECTIONS                  │
                    └──────────┬─────────┬────────────┘
                               │         │
                    ┌──────────▼─┐   ┌──▼───────────┐
                    │ MCP Protocol│   │ REST API     │
                    │ Endpoints   │   │ Endpoints    │
                    │             │   │              │
                    │ /mcp        │   │ /api/*       │
                    │ (existing)  │   │ (new)        │
                    └──────┬──────┘   └──────┬───────┘
                           │                 │
                    ┌──────▼──────┐   ┌──────▼───────┐
                    │   Cursor    │   │     n8n      │
                    │   Claude    │   │   Workflows  │
                    └─────────────┘   └──────────────┘
```

### Key Design Principles

1. **Code Reuse** - New endpoints use existing core functions
2. **Consistency** - Same security, logging, and error handling
3. **Simplicity** - REST API is intentionally simpler than MCP
4. **Flexibility** - Both protocols coexist independently

---

## Use Cases

### n8n AI Agent Workflow

**Scenario:** User asks "How many vehicles are there?"

```
1. n8n Webhook receives question
   ↓
2. HTTP Request: GET /api/connections (discover databases)
   ↓
3. HTTP Request: POST /api/schema (learn about vehicles table)
   ↓
4. AI Agent: Uses schema to craft SQL query
   ↓
5. HTTP Request: POST /api/query
   Body: {
     "connection": "prod_ro",
     "sql": "SELECT COUNT(*) FROM vehicles"
   }
   ↓
6. AI Agent: Formats response "There are 150 vehicles"
   ↓
7. Respond to user
```

### Specialized Tools Pattern

**Multiple AI tools with different domain knowledge:**

- **Vehicle Tool** - Knows about vehicles, fleet, maintenance tables
- **User Tool** - Knows about users, auth, profiles tables
- **Order Tool** - Knows about orders, payments, shipping tables

Each tool:
- Has specialized system prompt with relevant schema
- Uses same `/api/query` endpoint
- Accesses same database(s) via same MCP server
- Can answer domain-specific questions

---

## Migration Guide

### For Existing Users

**No action required!** Your existing setup continues to work.

### For New n8n Users

1. **Start the server** (as usual):
   ```bash
   docker compose up -d
   ```

2. **Get your MCP_TOKEN** from `.env`:
   ```bash
   grep MCP_TOKEN .env
   ```

3. **Test the API**:
   ```bash
   ./test-n8n-api.sh http://localhost:8799 YOUR_TOKEN
   ```

4. **Read the guide**:
   - [N8N_API_GUIDE.md](N8N_API_GUIDE.md)

5. **Build your n8n workflow**:
   - Use HTTP Request nodes
   - Configure authentication (Bearer token)
   - Create AI agent with system prompts

---

## Security Considerations

### Authentication
- ✅ Same authentication as MCP endpoints
- ✅ Bearer token required
- ✅ 401 Unauthorized if missing/invalid

### Query Safety
- ✅ Read-only by default (unless ALLOW_WRITE=true)
- ✅ Automatic LIMIT injection (5000 rows max)
- ✅ Query timeout enforcement (15s default)
- ✅ Parameterized query support (prevents SQL injection)

### Error Handling
- ✅ Detailed errors in development
- ⚠️ Consider sanitizing errors in production
- ✅ Error codes follow HTTP standards

---

## Testing

### Manual Testing

```bash
# Test new endpoints
./test-n8n-api.sh http://localhost:8799 YOUR_TOKEN

# Test backward compatibility
./test-server.sh http://localhost:8799 YOUR_TOKEN
```

### Expected Results

**New endpoints:**
- ✅ GET /api/connections returns 200
- ✅ POST /api/query returns 200 with results
- ✅ POST /api/schema returns 200 with schema
- ✅ Error handling returns appropriate codes

**Existing endpoints:**
- ✅ GET /healthz returns 200
- ✅ POST /mcp (initialize) returns 200
- ✅ POST /mcp (tools/list) returns 200
- ✅ POST /mcp (tools/call) returns 200

---

## Performance Impact

### Negligible
- New endpoints reuse existing code
- No additional overhead
- Same async I/O patterns
- Same database connection handling

### Metrics
- Memory: No significant increase
- CPU: No additional load
- Latency: Same as MCP endpoints

---

## Future Enhancements

### Potential Additions
- [ ] `/api/tables` - List all tables across all connections
- [ ] `/api/query/explain` - Get query execution plan
- [ ] `/api/batch` - Execute multiple queries in one request
- [ ] `/api/health` - Detailed health check with connection status
- [ ] Rate limiting per connection/token
- [ ] Query result caching

### Won't Break
Any future enhancements will:
- Be additive (new endpoints)
- Maintain backward compatibility
- Use versioning if breaking changes needed (`/api/v2/*`)

---

## Support

### Getting Help

1. **API Guide**: [N8N_API_GUIDE.md](N8N_API_GUIDE.md)
2. **Test Scripts**: Run `./test-n8n-api.sh`
3. **Examples**: See N8N_API_GUIDE.md for complete examples
4. **Troubleshooting**: Check logs with `docker compose logs`

### Common Issues

**401 Unauthorized**
- Check MCP_TOKEN in .env
- Verify Authorization header format

**404 Unknown Connection**
- Run GET /api/connections to see available connections
- Check .env for CONN_* variables

**403 Write Operations Disabled**
- Server is in read-only mode (default)
- Set ALLOW_WRITE=true if needed

---

## Credits

**Author:** Frederick Mbuya
**License:** MIT
**Version:** 1.1.0
**Date:** 2026-01-18

---

## Summary

This update successfully adds n8n integration capabilities while maintaining 100% backward compatibility with existing MCP clients. The new REST API endpoints provide a simpler, more accessible interface for n8n workflows and AI agents, enabling powerful database-driven automation.

**Key Achievement:** Dual-protocol support (MCP + REST) with shared security and zero breaking changes.
