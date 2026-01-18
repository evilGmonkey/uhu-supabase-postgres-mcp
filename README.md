# Supabase Postgres MCP Server

A production-ready Model Context Protocol (MCP) server that provides secure, multi-database SQL access to Supabase and PostgreSQL instances for AI coding assistants like Cursor and Claude Desktop.

## Features

- 🎯 **Multi-Database Support** - Connect to unlimited named Supabase/PostgreSQL databases
- 🔒 **Security First** - Read-only by default, bearer token authentication, query timeouts
- 🚀 **Production Ready** - Structured JSON logging, health checks, Docker support
- 🔌 **MCP Compatible** - Works with Cursor, Claude Desktop, and other MCP clients
- 🤖 **n8n Integration** - Simple REST API for n8n AI agents and automation workflows
- ⚡ **Real-time** - SSE (Server-Sent Events) for instant query results

## Quick Start

```bash
cd supabase-postgres-mcp-server
cp .env.example .env
# Edit .env with your database credentials
docker compose up -d
```

See [supabase-postgres-mcp-server/QUICKSTART.md](supabase-postgres-mcp-server/QUICKSTART.md) for detailed setup instructions.

## Documentation

- **[README.md](supabase-postgres-mcp-server/README.md)** - Comprehensive documentation
- **[QUICKSTART.md](supabase-postgres-mcp-server/QUICKSTART.md)** - 5-minute setup guide
- **[CURSOR_SETUP.md](supabase-postgres-mcp-server/CURSOR_SETUP.md)** - Cursor IDE integration
- **[N8N_API_GUIDE.md](supabase-postgres-mcp-server/N8N_API_GUIDE.md)** - n8n REST API integration guide
- **[PROJECT_SUMMARY.md](supabase-postgres-mcp-server/PROJECT_SUMMARY.md)** - Architecture overview

## License

MIT License - see [LICENSE](supabase-postgres-mcp-server/LICENSE) for details.
