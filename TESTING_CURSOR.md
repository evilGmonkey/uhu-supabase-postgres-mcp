# Testing MCP Tools in Cursor

## Prerequisites

1. **MCP Server Running**
   ```bash
   docker compose up -d
   ```

2. **Verify Server Health**
   ```bash
   curl http://gaia:8799/healthz
   ```
   Expected response:
   ```json
   {
     "ok": true,
     "connections": 2,
     "connection_names": ["prod_ro", "prod_rw"]
   }
   ```

3. **Cursor Configuration**
   Ensure `~/.cursor/mcp.json` contains:
   ```json
   {
     "mcpServers": {
       "postgres": {
         "url": "http://gaia:8799/mcp",
         "headers": {
           "Authorization": "Bearer YOUR_TOKEN_HERE"
         }
       }
     }
   }
   ```

## Testing the Tools

### Step 1: Restart Cursor
After updating the MCP server, restart Cursor completely to reload the MCP configuration.

### Step 2: Verify Tools Are Loaded
In Cursor, open Settings → Features → MCP and verify that the "postgres" server shows 3 tools:
- `postgres.list_connections`
- `postgres.get_schema`
- `postgres.query`

### Step 3: Test with Natural Language

Open Cursor Agent and try these prompts:

#### Test 1: List Connections
```
What database connections are available? Use MCP tools.
```
Expected: Should call `postgres.list_connections` and show available connections.

#### Test 2: Explore Schema
```
What tables are available in the prod_ro database?
```
Expected: Should call `postgres.get_schema` with connection="prod_ro" and list all tables.

#### Test 3: Get Table Columns
```
Show me the columns in the users table from prod_ro
```
Expected: Should call `postgres.get_schema` with connection="prod_ro" and table="users".

#### Test 4: Execute Query
```
Get the count of records in the vehicles table using prod_ro
```
Expected: Should call `postgres.query` with connection="prod_ro" and sql="SELECT COUNT(*) FROM vehicles".

## Troubleshooting

### No Tools Showing in Cursor

**Problem**: "No MCP resources available" or empty tools list

**Solutions**:
1. Check server logs: `docker compose logs -f`
2. Verify authentication token matches between .env and mcp.json
3. Test MCP endpoint manually:
   ```bash
   curl -H "Authorization: Bearer YOUR_TOKEN" \
        -H "Content-Type: application/json" \
        -X POST http://gaia:8799/mcp \
        -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
   ```
   Expected response should include all three tools.

4. Restart Cursor completely (not just reload window)

### Tools Not Being Called

**Problem**: Cursor sees tools but doesn't use them

**Solutions**:
1. Be explicit: "Use MCP tools to..." or "Use postgres.list_connections to..."
2. Check Cursor's tool call approval settings
3. Try simpler prompts first (like listing connections)

### Connection Errors

**Problem**: Tools fail with connection errors

**Solutions**:
1. Verify database credentials in .env file
2. Check network connectivity from Cursor to server
3. Review server logs for authentication or database connection issues

## Manual Testing (Without Cursor)

You can test the MCP tools directly using curl:

### List Tools
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -X POST http://gaia:8799/mcp \
     -d '{
       "jsonrpc": "2.0",
       "id": 1,
       "method": "tools/list"
     }'
```

### Test postgres.list_connections
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -X POST http://gaia:8799/mcp \
     -d '{
       "jsonrpc": "2.0",
       "id": 2,
       "method": "tools/call",
       "params": {
         "name": "postgres.list_connections",
         "arguments": {}
       }
     }'
```

### Test postgres.get_schema (all tables)
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -X POST http://gaia:8799/mcp \
     -d '{
       "jsonrpc": "2.0",
       "id": 3,
       "method": "tools/call",
       "params": {
         "name": "postgres.get_schema",
         "arguments": {
           "connection": "prod_ro"
         }
       }
     }'
```

### Test postgres.get_schema (specific table)
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -X POST http://gaia:8799/mcp \
     -d '{
       "jsonrpc": "2.0",
       "id": 4,
       "method": "tools/call",
       "params": {
         "name": "postgres.get_schema",
         "arguments": {
           "connection": "prod_ro",
           "table": "users"
         }
       }
     }'
```

### Test postgres.query
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -X POST http://gaia:8799/mcp \
     -d '{
       "jsonrpc": "2.0",
       "id": 5,
       "method": "tools/call",
       "params": {
         "name": "postgres.query",
         "arguments": {
           "connection": "prod_ro",
           "sql": "SELECT version()"
         }
       }
     }'
```

## Expected Behavior

When working correctly, you should see:
1. Cursor recognizes the MCP server and loads 3 tools
2. When you ask database-related questions, Cursor autonomously calls appropriate tools
3. Tool responses appear in Cursor's context and inform AI responses
4. No manual JSON formatting needed - just natural language queries

## Success Criteria

- [ ] All 3 tools appear in Cursor's MCP settings
- [ ] `postgres.list_connections` returns configured connections
- [ ] `postgres.get_schema` returns table lists and column details
- [ ] `postgres.query` executes SQL and returns results
- [ ] Cursor AI can autonomously discover and use tools
- [ ] Error messages are clear and actionable

## Next Steps

Once testing is complete and tools work in Cursor:
1. Document any issues or unexpected behavior
2. Test with real-world database queries
3. Verify read-only enforcement works correctly
4. Consider adding more specific tools for common operations
