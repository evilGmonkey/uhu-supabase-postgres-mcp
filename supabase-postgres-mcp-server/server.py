import os
import json
import asyncio
import time
import logging
import re
from typing import Optional, Dict, Any, Set, List
from datetime import datetime

import psycopg
from psycopg import errors as pg_errors
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse, StreamingResponse
from fastapi.middleware.cors import CORSMiddleware

# ================================================================================
# Multi-Connection Supabase/Postgres MCP Server
# ================================================================================
# Author: Frederick Mbuya
# License: MIT
#
# A Model Context Protocol (MCP) server that provides read-only SQL access
# to multiple named Supabase/PostgreSQL databases via HTTP + SSE transport.
#
# Features:
# - Multiple named database connections (CONN_<name>_*)
# - Read-only mode with optional write access (ALLOW_WRITE)
# - Automatic query limits and timeouts
# - Structured JSON logging with request tracking
# - Comprehensive error handling
# - Bearer token authentication
# - Docker-ready with health checks
#
# Transport:
# - GET /mcp  -> SSE stream for real-time updates
# - POST /mcp -> JSON-RPC 2.0 requests (initialize, tools/list, tools/call)
#
# Tool:
# - sql.query(connection, sql, params?) -> Execute SQL on named connection
# ================================================================================

APP = FastAPI(title="Supabase Postgres MCP Server", version="1.0.0")

# CORS middleware for cross-origin requests
APP.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ================================================================================
# Logging Configuration
# ================================================================================

class JSONFormatter(logging.Formatter):
    """Structured JSON log formatter for production observability."""

    def format(self, record: logging.LogRecord) -> str:
        log_data = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        # Add exception info if present
        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)

        # Add custom fields if present
        for field in ["request_id", "method", "duration_ms", "connection", "error_code"]:
            if hasattr(record, field):
                log_data[field] = getattr(record, field)

        return json.dumps(log_data, ensure_ascii=False)


# Configure logger
log_level = os.getenv("LOG_LEVEL", "INFO").upper()
handler = logging.StreamHandler()

# Use JSON logging in production, simple format in development
if os.getenv("LOG_FORMAT", "json").lower() == "json":
    handler.setFormatter(JSONFormatter())
else:
    handler.setFormatter(logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    ))

logger = logging.getLogger("mcp")
logger.setLevel(getattr(logging, log_level, logging.INFO))
logger.addHandler(handler)
logger.propagate = False

# ================================================================================
# Configuration
# ================================================================================

MCP_TOKEN = os.getenv("MCP_TOKEN", "")
MCP_SERVER_NAME = os.getenv("MCP_SERVER_NAME", "supabase-postgres-mcp")
MCP_PATH = os.getenv("MCP_PATH", "/mcp")
MCP_HOST = os.getenv("MCP_HOST", "0.0.0.0")
MCP_PORT = int(os.getenv("MCP_PORT", "8799"))

# Query limits and timeouts
ROW_LIMIT = int(os.getenv("ROW_LIMIT", "5000"))
QUERY_TIMEOUT_MS = int(os.getenv("QUERY_TIMEOUT_MS", "15000"))
ALLOW_WRITE = os.getenv("ALLOW_WRITE", "false").lower() == "true"

# ================================================================================
# Database Connection Management
# ================================================================================

def load_connections() -> Dict[str, str]:
    """
    Load all database connections from environment variables.

    Pattern: CONN_<name>_HOST, CONN_<name>_PORT, CONN_<name>_DBNAME,
             CONN_<name>_USER, CONN_<name>_PASSWORD

    Returns:
        Dictionary mapping connection names to PostgreSQL connection strings.

    Example:
        CONN_prod_HOST=db.example.com
        CONN_prod_PORT=5432
        CONN_prod_DBNAME=postgres
        CONN_prod_USER=mcp_ro
        CONN_prod_PASSWORD=secret

        -> {"prod": "postgresql://mcp_ro:secret@db.example.com:5432/postgres"}
    """
    connections: Dict[str, str] = {}
    connection_names: Set[str] = set()

    # Discover all connection names by looking for CONN_*_HOST variables
    for key in os.environ:
        if key.startswith("CONN_") and key.endswith("_HOST"):
            # Extract connection name: CONN_<name>_HOST -> <name>
            name = key[5:-5]  # Remove "CONN_" prefix and "_HOST" suffix
            connection_names.add(name)

    # Build connection string for each discovered connection
    for name in connection_names:
        host = os.getenv(f"CONN_{name}_HOST")
        port = os.getenv(f"CONN_{name}_PORT", "5432")
        dbname = os.getenv(f"CONN_{name}_DBNAME")
        user = os.getenv(f"CONN_{name}_USER")
        password = os.getenv(f"CONN_{name}_PASSWORD", "")
        sslmode = os.getenv(f"CONN_{name}_SSLMODE", "prefer")

        # Validate required fields
        if not host or not dbname or not user:
            logger.warning(
                f"Skipping connection '{name}': missing required fields (host, dbname, or user)",
                extra={"connection": name}
            )
            continue

        # Build PostgreSQL connection string
        conn_str = f"postgresql://{user}:{password}@{host}:{port}/{dbname}?sslmode={sslmode}"
        connections[name] = conn_str

        # Log connection (without password)
        safe_str = f"postgresql://{user}:***@{host}:{port}/{dbname}?sslmode={sslmode}"
        logger.info(f"Loaded connection: {name} -> {safe_str}")

    if not connections:
        logger.error("No database connections configured! Define CONN_<name>_* variables in environment")
    else:
        logger.info(f"Total connections loaded: {len(connections)}")

    return connections


# Load connections at startup
CONNECTIONS = load_connections()

# ================================================================================
# SSE (Server-Sent Events) Management
# ================================================================================

SUBSCRIBERS: Set[asyncio.Queue] = set()
SUB_LOCK = asyncio.Lock()
PENDING: List[str] = []  # Buffer for messages sent before SSE connects


async def publish_sse_message(obj: Dict[str, Any]):
    """
    Publish a JSON-RPC message to all SSE subscribers.
    If no subscribers are connected, buffer the message for later delivery.
    """
    data = json.dumps(obj, ensure_ascii=False)

    async with SUB_LOCK:
        if not SUBSCRIBERS:
            PENDING.append(data)
            return

        dead = []
        for q in list(SUBSCRIBERS):
            try:
                q.put_nowait(data)
            except asyncio.QueueFull:
                dead.append(q)

        # Clean up dead subscribers
        for q in dead:
            SUBSCRIBERS.discard(q)

# ================================================================================
# Authentication
# ================================================================================

def auth_ok(req: Request) -> bool:
    """
    Verify request authentication using MCP_TOKEN.

    Supports three methods:
    1. Authorization: Bearer <token>
    2. X-MCP-Token: <token>
    3. Query parameter: ?token=<token>

    Returns True if MCP_TOKEN is empty (open access - not recommended).
    """
    if not MCP_TOKEN:
        logger.warning("MCP_TOKEN not set - allowing unauthenticated access")
        return True

    # Check Authorization header
    auth = req.headers.get("authorization", "")
    if auth.startswith("Bearer "):
        return auth.split(" ", 1)[1] == MCP_TOKEN

    # Check custom header
    if req.headers.get("x-mcp-token", "") == MCP_TOKEN:
        return True

    # Check query parameter
    return req.query_params.get("token") == MCP_TOKEN

# ================================================================================
# SQL Query Execution
# ================================================================================

def is_readonly(sql: str) -> bool:
    """
    Check if SQL query contains write operations.

    Returns True if:
    - ALLOW_WRITE is enabled, OR
    - Query contains no write operations

    Blocks: INSERT, UPDATE, DELETE, DROP, ALTER, CREATE, GRANT, REVOKE, TRUNCATE
    """
    if ALLOW_WRITE:
        return True

    if not sql:
        return True

    banned = (
        "insert", "update", "delete", "drop", "alter",
        "create", "grant", "revoke", "truncate"
    )

    lower = sql.strip().lower()

    # Use word boundaries to match complete SQL commands only
    # This prevents false positives like "created_at" being blocked
    for word in banned:
        if re.search(r'\b' + re.escape(word) + r'\b', lower):
            return False

    return True


async def run_sql(connection: str, sql: str, params: Optional[list] = None) -> Dict[str, Any]:
    """
    Execute a SQL query against the specified named connection.

    Args:
        connection: Name of the database connection
        sql: SQL query to execute
        params: Optional query parameters for parameterized queries

    Returns:
        Dictionary with 'rows' key containing query results

    Raises:
        ValueError: Unknown connection, missing config, SQL syntax errors
        PermissionError: Insufficient database privileges
        TimeoutError: Query exceeded timeout
        ConnectionError: Database connection failed
    """
    # Validate connection exists
    if connection not in CONNECTIONS:
        available = ", ".join(sorted(CONNECTIONS.keys())) if CONNECTIONS else "none"
        raise ValueError(
            f"Unknown connection: '{connection}'. Available connections: {available}"
        )

    conn_url = CONNECTIONS[connection]
    options = f"-c statement_timeout={QUERY_TIMEOUT_MS}"

    try:
        async with await psycopg.AsyncConnection.connect(conn_url, options=options) as aconn:
            async with aconn.cursor(row_factory=psycopg.rows.dict_row) as cur:
                # Add LIMIT clause if SELECT query doesn't have one
                sql_mod = sql
                if "select" in sql.lower() and " limit " not in sql.lower():
                    sql_mod = f"{sql.rstrip().rstrip(';')} LIMIT {ROW_LIMIT}"
                    logger.debug(f"Auto-added LIMIT {ROW_LIMIT} to query")

                try:
                    await cur.execute(sql_mod, params or [])
                except pg_errors.SyntaxError as e:
                    raise ValueError(f"SQL syntax error: {str(e)}") from e
                except pg_errors.UndefinedTable as e:
                    raise ValueError(f"Table does not exist: {str(e)}") from e
                except pg_errors.UndefinedColumn as e:
                    raise ValueError(f"Column does not exist: {str(e)}") from e
                except pg_errors.InsufficientPrivilege as e:
                    raise PermissionError(f"Insufficient privileges: {str(e)}") from e
                except pg_errors.QueryCanceled:
                    raise TimeoutError(
                        f"Query exceeded timeout of {QUERY_TIMEOUT_MS}ms"
                    ) from None
                except pg_errors.Error as e:
                    raise ValueError(f"Database error: {str(e)}") from e

                # Fetch results
                try:
                    rows = await cur.fetchall()
                    return {"rows": rows, "row_count": len(rows)}
                except psycopg.ProgrammingError:
                    # Query doesn't return rows (e.g., DDL)
                    return {"rows": [], "row_count": 0}

    except psycopg.OperationalError as e:
        raise ConnectionError(f"Failed to connect to database '{connection}': {str(e)}") from e
    except (TimeoutError, ValueError, PermissionError):
        raise
    except Exception as e:
        raise RuntimeError(f"Unexpected error executing query: {str(e)}") from e

# ================================================================================
# MCP Tool Catalog
# ================================================================================

def tool_catalog() -> Dict[str, List[Dict[str, Any]]]:
    """
    Return the MCP tool catalog with available connections.
    """
    available_connections = sorted(CONNECTIONS.keys())
    connection_list = ", ".join(available_connections) if available_connections else "none configured"

    return {
        "tools": [
            {
                "name": "sql.query",
                "description": f"Execute a SQL query against a named Supabase/PostgreSQL database. Available connections: {connection_list}",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "connection": {
                            "type": "string",
                            "description": f"Name of the database connection to use. Available: {connection_list}",
                            "enum": available_connections if available_connections else []
                        },
                        "sql": {
                            "type": "string",
                            "description": "SQL query to execute (SELECT, or other if ALLOW_WRITE=true)"
                        },
                        "params": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Optional parameters for parameterized queries (use $1, $2, etc.)"
                        }
                    },
                    "required": ["connection", "sql"],
                    "additionalProperties": False
                }
            }
        ]
    }

# ================================================================================
# HTTP Routes
# ================================================================================

@APP.get("/healthz")
async def health():
    """Health check endpoint."""
    return {
        "ok": True,
        "time": int(time.time()),
        "server": MCP_SERVER_NAME,
        "connections": len(CONNECTIONS),
        "connection_names": sorted(CONNECTIONS.keys())
    }


# ================================================================================
# n8n-Friendly REST API Endpoints
# ================================================================================
# These simplified REST endpoints are designed for easy integration with n8n
# and other tools that don't need the full MCP protocol complexity.
# All existing MCP endpoints remain fully functional.
# ================================================================================

@APP.get("/api/connections")
async def api_list_connections(request: Request):
    """
    List all available database connections.

    Returns:
        {
            "ok": true,
            "connections": [
                {
                    "name": "prod_ro",
                    "description": "Production read-only"
                },
                ...
            ]
        }
    """
    if not auth_ok(request):
        raise HTTPException(status_code=401, detail="Unauthorized")

    connections_list = [
        {"name": name, "description": f"Database connection: {name}"}
        for name in sorted(CONNECTIONS.keys())
    ]

    return {
        "ok": True,
        "connections": connections_list,
        "count": len(connections_list)
    }


@APP.post("/api/query")
async def api_query(request: Request):
    """
    Execute a SQL query against a named database connection.

    Simple REST endpoint for n8n - no MCP protocol overhead.

    Request body:
        {
            "connection": "prod_ro",
            "sql": "SELECT COUNT(*) FROM vehicles",
            "params": ["optional", "parameters"]  // optional
        }

    Response:
        {
            "ok": true,
            "rows": [...],
            "row_count": 10,
            "connection": "prod_ro",
            "execution_time_ms": 45
        }

    Error response:
        {
            "ok": false,
            "error": "error message",
            "error_code": 400
        }
    """
    if not auth_ok(request):
        raise HTTPException(status_code=401, detail="Unauthorized")

    start_time = time.time()

    try:
        payload = await request.json()
    except Exception:
        return JSONResponse(
            status_code=400,
            content={"ok": False, "error": "Invalid JSON", "error_code": 400}
        )

    connection = payload.get("connection", "")
    sql = payload.get("sql", "")
    params = payload.get("params", [])

    # Validate required fields
    if not connection:
        return JSONResponse(
            status_code=400,
            content={"ok": False, "error": "Missing required field: connection", "error_code": 400}
        )

    if not sql:
        return JSONResponse(
            status_code=400,
            content={"ok": False, "error": "Missing required field: sql", "error_code": 400}
        )

    # Validate connection exists
    if connection not in CONNECTIONS:
        available = ", ".join(sorted(CONNECTIONS.keys())) if CONNECTIONS else "none"
        return JSONResponse(
            status_code=404,
            content={
                "ok": False,
                "error": f"Unknown connection: '{connection}'. Available: {available}",
                "error_code": 404
            }
        )

    # Check read-only mode
    if not is_readonly(sql):
        return JSONResponse(
            status_code=403,
            content={
                "ok": False,
                "error": "Write operations are disabled. Set ALLOW_WRITE=true to enable.",
                "error_code": 403
            }
        )

    # Execute query
    try:
        result = await run_sql(connection, sql, params)
        execution_time_ms = int((time.time() - start_time) * 1000)

        logger.info(
            f"API query executed successfully on '{connection}'",
            extra={
                "connection": connection,
                "row_count": result.get("row_count", 0),
                "duration_ms": execution_time_ms
            }
        )

        return {
            "ok": True,
            "rows": result["rows"],
            "row_count": result["row_count"],
            "connection": connection,
            "execution_time_ms": execution_time_ms
        }

    except ValueError as e:
        logger.warning(f"API query validation error: {e}")
        return JSONResponse(
            status_code=400,
            content={"ok": False, "error": str(e), "error_code": 400}
        )

    except PermissionError as e:
        logger.warning(f"API query permission error: {e}")
        return JSONResponse(
            status_code=403,
            content={"ok": False, "error": str(e), "error_code": 403}
        )

    except ConnectionError as e:
        logger.error(f"API query connection error: {e}")
        return JSONResponse(
            status_code=503,
            content={"ok": False, "error": "Database unavailable", "error_code": 503}
        )

    except TimeoutError as e:
        logger.warning(f"API query timeout: {e}")
        return JSONResponse(
            status_code=408,
            content={"ok": False, "error": str(e), "error_code": 408}
        )

    except Exception as e:
        logger.exception(f"API query unexpected error: {e}")
        return JSONResponse(
            status_code=500,
            content={"ok": False, "error": f"Internal error: {str(e)}", "error_code": 500}
        )


@APP.post("/api/schema")
async def api_get_schema(request: Request):
    """
    Get database schema information for a connection.

    Useful for AI agents to understand table structures.

    Request body:
        {
            "connection": "prod_ro",
            "table": "vehicles"  // optional - if omitted, returns all tables
        }

    Response (all tables):
        {
            "ok": true,
            "connection": "prod_ro",
            "tables": [
                {
                    "table_name": "vehicles",
                    "table_schema": "public"
                },
                ...
            ]
        }

    Response (specific table):
        {
            "ok": true,
            "connection": "prod_ro",
            "table": "vehicles",
            "columns": [
                {
                    "column_name": "id",
                    "data_type": "integer",
                    "is_nullable": "NO"
                },
                ...
            ]
        }
    """
    if not auth_ok(request):
        raise HTTPException(status_code=401, detail="Unauthorized")

    try:
        payload = await request.json()
    except Exception:
        return JSONResponse(
            status_code=400,
            content={"ok": False, "error": "Invalid JSON", "error_code": 400}
        )

    connection = payload.get("connection", "")
    table = payload.get("table", "")

    if not connection:
        return JSONResponse(
            status_code=400,
            content={"ok": False, "error": "Missing required field: connection", "error_code": 400}
        )

    if connection not in CONNECTIONS:
        available = ", ".join(sorted(CONNECTIONS.keys())) if CONNECTIONS else "none"
        return JSONResponse(
            status_code=404,
            content={
                "ok": False,
                "error": f"Unknown connection: '{connection}'. Available: {available}",
                "error_code": 404
            }
        )

    try:
        if table:
            # Get columns for specific table
            sql = """
                SELECT
                    column_name,
                    data_type,
                    is_nullable,
                    column_default
                FROM information_schema.columns
                WHERE table_schema = 'public'
                AND table_name = $1
                ORDER BY ordinal_position
            """
            result = await run_sql(connection, sql, [table])

            return {
                "ok": True,
                "connection": connection,
                "table": table,
                "columns": result["rows"]
            }
        else:
            # Get all tables
            sql = """
                SELECT
                    table_name,
                    table_schema
                FROM information_schema.tables
                WHERE table_schema = 'public'
                AND table_type = 'BASE TABLE'
                ORDER BY table_name
            """
            result = await run_sql(connection, sql)

            return {
                "ok": True,
                "connection": connection,
                "tables": result["rows"]
            }

    except Exception as e:
        logger.exception(f"API schema query error: {e}")
        return JSONResponse(
            status_code=500,
            content={"ok": False, "error": f"Failed to retrieve schema: {str(e)}", "error_code": 500}
        )


@APP.get(MCP_PATH)
async def mcp_sse(request: Request):
    """
    SSE (Server-Sent Events) endpoint for real-time MCP message streaming.
    Cursor and other MCP clients connect here to receive async responses.
    """
    if not auth_ok(request):
        raise HTTPException(status_code=401, detail="Unauthorized")

    q: asyncio.Queue = asyncio.Queue(maxsize=200)

    async def gen():
        # Send initial ready event
        yield 'event: ready\ndata: {"ok": true}\n\n'

        # Register subscriber and flush any pending messages
        async with SUB_LOCK:
            SUBSCRIBERS.add(q)
            while PENDING:
                data = PENDING.pop(0)
                yield f"event: message\ndata: {data}\n\n"

        try:
            while True:
                try:
                    # Wait for messages with timeout for keep-alive
                    data = await asyncio.wait_for(q.get(), timeout=15.0)
                    yield f"event: message\ndata: {data}\n\n"
                except asyncio.TimeoutError:
                    # Send keep-alive comment
                    yield ": keep-alive\n\n"

                # Check if client disconnected
                if await request.is_disconnected():
                    break
        finally:
            # Clean up subscriber
            async with SUB_LOCK:
                SUBSCRIBERS.discard(q)

    return StreamingResponse(
        gen(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@APP.post(MCP_PATH)
async def mcp_endpoint(request: Request):
    """
    Main MCP endpoint for JSON-RPC 2.0 requests.

    Handles:
    - initialize / server/initialize
    - server/info
    - tools/list
    - tools/call
    - prompts/list
    - resources/list
    """
    if not auth_ok(request):
        raise HTTPException(status_code=401, detail="Unauthorized")

    # Parse JSON-RPC request
    try:
        payload = await request.json()
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid JSON")

    _id = payload.get("id")
    method = payload.get("method")
    params = payload.get("params", {}) or {}
    start_time = time.time()

    logger.info("MCP request received", extra={"method": method, "request_id": _id})

    # JSON-RPC notifications (no id) - don't respond
    if _id is None and isinstance(method, str) and method.startswith("notifications/"):
        return JSONResponse({"ok": True})

    # Build JSON-RPC reply
    reply: Dict[str, Any]

    # === INITIALIZE ===
    if method in ("initialize", "server/initialize"):
        result = {
            "protocolVersion": "2025-03-26",
            "capabilities": {
                "logging": {},
                "prompts": {"listChanged": True},
                "resources": {"subscribe": False, "listChanged": True},
                "tools": {"listChanged": True}
            },
            "serverInfo": {
                "name": MCP_SERVER_NAME,
                "version": "1.0.0"
            },
            "instructions": f"Multi-database MCP server with {len(CONNECTIONS)} connection(s): {', '.join(sorted(CONNECTIONS.keys()))}"
        }
        reply = {"jsonrpc": "2.0", "id": _id, "result": result}

    # === SERVER INFO ===
    elif method == "server/info":
        result = {
            "protocolVersion": "2025-03-26",
            "capabilities": {
                "logging": {},
                "prompts": {"listChanged": True},
                "resources": {"subscribe": False, "listChanged": True},
                "tools": {"listChanged": True}
            },
            "serverInfo": {
                "name": MCP_SERVER_NAME,
                "version": "1.0.0"
            }
        }
        reply = {"jsonrpc": "2.0", "id": _id, "result": result}

    # === TOOLS LIST ===
    elif method in ("tools/list", "server/tools/list", "listTools"):
        reply = {"jsonrpc": "2.0", "id": _id, "result": tool_catalog()}

    # === PROMPTS LIST ===
    elif method in ("prompts/list", "server/prompts/list"):
        reply = {"jsonrpc": "2.0", "id": _id, "result": {"prompts": []}}

    # === RESOURCES LIST ===
    elif method in ("resources/list", "server/resources/list"):
        reply = {"jsonrpc": "2.0", "id": _id, "result": {"resources": []}}

    # === TOOL CALL ===
    elif method == "tools/call":
        name = params.get("name")
        args = params.get("arguments", {})

        if name == "sql.query":
            connection = args.get("connection", "")
            sql = args.get("sql", "")
            query_params = args.get("params", [])

            # Validate required parameters
            if not connection:
                reply = {
                    "jsonrpc": "2.0",
                    "id": _id,
                    "error": {
                        "code": 400,
                        "message": "Missing required parameter: connection"
                    }
                }
            elif not sql:
                reply = {
                    "jsonrpc": "2.0",
                    "id": _id,
                    "error": {
                        "code": 400,
                        "message": "Missing required parameter: sql"
                    }
                }
            elif connection not in CONNECTIONS:
                available = ", ".join(sorted(CONNECTIONS.keys())) if CONNECTIONS else "none"
                reply = {
                    "jsonrpc": "2.0",
                    "id": _id,
                    "error": {
                        "code": 400,
                        "message": f"Unknown connection: '{connection}'. Available: {available}"
                    }
                }
            elif not is_readonly(sql):
                reply = {
                    "jsonrpc": "2.0",
                    "id": _id,
                    "error": {
                        "code": 403,
                        "message": "Write operations are disabled. Set ALLOW_WRITE=true to enable."
                    }
                }
            else:
                # Execute query
                try:
                    result = await run_sql(connection, sql, query_params)

                    # Format result as MCP content
                    content = {
                        "content": [
                            {
                                "type": "text",
                                "text": json.dumps(result, ensure_ascii=False, default=str)
                            }
                        ]
                    }
                    reply = {"jsonrpc": "2.0", "id": _id, "result": content}

                    logger.info(
                        f"Query executed successfully on '{connection}'",
                        extra={
                            "request_id": _id,
                            "connection": connection,
                            "row_count": result.get("row_count", 0)
                        }
                    )

                except ValueError as e:
                    # Client errors (syntax, missing tables, etc.)
                    reply = {
                        "jsonrpc": "2.0",
                        "id": _id,
                        "error": {"code": 400, "message": str(e)}
                    }
                    logger.warning(f"Query validation error: {e}", extra={"request_id": _id})

                except PermissionError as e:
                    # Permission errors
                    reply = {
                        "jsonrpc": "2.0",
                        "id": _id,
                        "error": {"code": 403, "message": str(e)}
                    }
                    logger.warning(f"Permission error: {e}", extra={"request_id": _id})

                except ConnectionError as e:
                    # Database connection issues
                    reply = {
                        "jsonrpc": "2.0",
                        "id": _id,
                        "error": {"code": 503, "message": "Database unavailable"}
                    }
                    logger.error(f"Database connection error: {e}", extra={"request_id": _id})

                except TimeoutError as e:
                    # Query timeout
                    reply = {
                        "jsonrpc": "2.0",
                        "id": _id,
                        "error": {"code": 408, "message": str(e)}
                    }
                    logger.warning(f"Query timeout: {e}", extra={"request_id": _id})

                except Exception as e:
                    # Unexpected errors
                    reply = {
                        "jsonrpc": "2.0",
                        "id": _id,
                        "error": {"code": 500, "message": f"Internal error: {str(e)}"}
                    }
                    logger.exception(f"Unexpected error: {e}", extra={"request_id": _id})
        else:
            reply = {
                "jsonrpc": "2.0",
                "id": _id,
                "error": {"code": 404, "message": f"Unknown tool: {name}"}
            }

    # === UNKNOWN METHOD ===
    else:
        reply = {
            "jsonrpc": "2.0",
            "id": _id,
            "error": {"code": -32601, "message": f"Method not found: {method}"}
        }

    # Publish to SSE subscribers
    await publish_sse_message(reply)

    # Log request completion
    duration_ms = int((time.time() - start_time) * 1000)
    log_level = logging.INFO if "error" not in reply else logging.WARNING
    logger.log(
        log_level,
        "MCP request completed",
        extra={
            "method": method,
            "request_id": _id,
            "duration_ms": duration_ms,
            "has_error": "error" in reply
        }
    )

    # Return reply in HTTP body (helps some clients)
    return JSONResponse(reply)


# ================================================================================
# Main Entry Point
# ================================================================================

if __name__ == "__main__":
    if not CONNECTIONS:
        logger.error("No database connections configured. Please set CONN_<name>_* environment variables.")
        logger.error("Example: CONN_prod_HOST=db.example.com CONN_prod_DBNAME=postgres CONN_prod_USER=mcp_ro")

    import uvicorn

    logger.info(f"Starting {MCP_SERVER_NAME} on {MCP_HOST}:{MCP_PORT}")
    logger.info(f"MCP endpoint: {MCP_PATH}")
    logger.info(f"Configured connections: {', '.join(sorted(CONNECTIONS.keys())) if CONNECTIONS else 'none'}")
    logger.info(f"Read-only mode: {not ALLOW_WRITE}")

    uvicorn.run(APP, host=MCP_HOST, port=MCP_PORT, log_level="info")
