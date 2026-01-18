#!/bin/bash

# =============================================================================
# Interactive MCP Role Setup Script
# =============================================================================
# Author: Frederick Mbuya
# License: MIT
#
# This script interactively creates both mcp_readonly and mcp_readwrite roles
# and outputs the connection configuration for your .env file.
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}===============================================================================${NC}"
echo -e "${BLUE}MCP Database Role Setup${NC}"
echo -e "${BLUE}===============================================================================${NC}"
echo ""

# =============================================================================
# Prompt for database connection details
# =============================================================================

echo -e "${CYAN}Step 1: Database Connection Information${NC}"
echo ""

read -p "PostgreSQL Host [localhost]: " DB_HOST
DB_HOST=${DB_HOST:-localhost}

read -p "PostgreSQL Port [5432]: " DB_PORT
DB_PORT=${DB_PORT:-5432}

read -p "Database Name [postgres]: " DB_NAME
DB_NAME=${DB_NAME:-postgres}

read -p "Admin Username [postgres]: " ADMIN_USER
ADMIN_USER=${ADMIN_USER:-postgres}

echo -n "Admin Password: "
read -s ADMIN_PASSWORD
echo ""

if [ -z "$ADMIN_PASSWORD" ]; then
    echo -e "${RED}Error: Admin password cannot be empty${NC}"
    exit 1
fi

echo ""

# =============================================================================
# Prompt for connection name
# =============================================================================

echo -e "${CYAN}Step 2: MCP Connection Configuration${NC}"
echo ""
echo "This will be used in your .env file as CONN_<name>_ro and CONN_<name>_rw"
echo "Examples: prod, staging, dev, office, etc."
echo ""

read -p "Connection Name [prod]: " CONN_NAME
CONN_NAME=${CONN_NAME:-prod}

# Validate connection name (alphanumeric and underscores only)
if [[ ! "$CONN_NAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo -e "${RED}Error: Connection name must contain only letters, numbers, and underscores${NC}"
    exit 1
fi

echo ""

# =============================================================================
# Generate strong passwords for MCP roles
# =============================================================================

echo -e "${CYAN}Step 3: Generating secure passwords for MCP roles...${NC}"
echo ""

READONLY_PASS=$(openssl rand -base64 32)
READWRITE_PASS=$(openssl rand -base64 32)

echo -e "${GREEN}✓ Generated read-only password${NC}"
echo -e "${GREEN}✓ Generated read-write password${NC}"
echo ""

# =============================================================================
# Test database connection
# =============================================================================

echo -e "${CYAN}Step 4: Testing database connection...${NC}"
echo ""

if ! PGPASSWORD="$ADMIN_PASSWORD" psql \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$ADMIN_USER" \
    -d "$DB_NAME" \
    -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${RED}✗ Failed to connect to database${NC}"
    echo -e "${RED}Please check your connection details and try again${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Successfully connected to database${NC}"
echo ""

# =============================================================================
# Create MCP roles
# =============================================================================

echo -e "${CYAN}Step 5: Creating MCP roles...${NC}"
echo ""

PGPASSWORD="$ADMIN_PASSWORD" psql \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$ADMIN_USER" \
    -d "$DB_NAME" \
    -v ON_ERROR_STOP=1 \
    << EOF

-- Create read-only role
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'mcp_readonly') THEN
        CREATE ROLE mcp_readonly LOGIN PASSWORD '$READONLY_PASS';
        RAISE NOTICE 'Created role: mcp_readonly';
    ELSE
        -- Update password if role exists
        ALTER ROLE mcp_readonly PASSWORD '$READONLY_PASS';
        RAISE NOTICE 'Role mcp_readonly already exists, updated password';
    END IF;
END
\$\$;

GRANT CONNECT ON DATABASE $DB_NAME TO mcp_readonly;
GRANT USAGE ON SCHEMA public TO mcp_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO mcp_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO mcp_readonly;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO mcp_readonly;

-- Create read-write role
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'mcp_readwrite') THEN
        CREATE ROLE mcp_readwrite LOGIN PASSWORD '$READWRITE_PASS';
        RAISE NOTICE 'Created role: mcp_readwrite';
    ELSE
        -- Update password if role exists
        ALTER ROLE mcp_readwrite PASSWORD '$READWRITE_PASS';
        RAISE NOTICE 'Role mcp_readwrite already exists, updated password';
    END IF;
END
\$\$;

GRANT CONNECT ON DATABASE $DB_NAME TO mcp_readwrite;
GRANT USAGE ON SCHEMA public TO mcp_readwrite;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO mcp_readwrite;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO mcp_readwrite;
GRANT USAGE, UPDATE ON ALL SEQUENCES IN SCHEMA public TO mcp_readwrite;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, UPDATE ON SEQUENCES TO mcp_readwrite;

-- Verify roles
SELECT rolname, rolcanlogin FROM pg_roles WHERE rolname IN ('mcp_readonly', 'mcp_readwrite');

EOF

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Successfully created MCP roles${NC}"
else
    echo ""
    echo -e "${RED}✗ Failed to create MCP roles${NC}"
    exit 1
fi

echo ""

# =============================================================================
# Determine SSL mode
# =============================================================================

if [ "$DB_HOST" = "localhost" ] || [ "$DB_HOST" = "127.0.0.1" ]; then
    SSLMODE="prefer"
else
    SSLMODE="require"
fi

# =============================================================================
# Output configuration for .env file
# =============================================================================

echo -e "${BLUE}===============================================================================${NC}"
echo -e "${BLUE}Setup Complete!${NC}"
echo -e "${BLUE}===============================================================================${NC}"
echo ""
echo -e "${GREEN}Add the following to your .env file:${NC}"
echo ""
echo -e "${YELLOW}# Read-Only Connection (${CONN_NAME}_ro)${NC}"
echo "CONN_${CONN_NAME}_ro_HOST=$DB_HOST"
echo "CONN_${CONN_NAME}_ro_PORT=$DB_PORT"
echo "CONN_${CONN_NAME}_ro_DBNAME=$DB_NAME"
echo "CONN_${CONN_NAME}_ro_USER=mcp_readonly"
echo "CONN_${CONN_NAME}_ro_PASSWORD=$READONLY_PASS"
echo "CONN_${CONN_NAME}_ro_SSLMODE=$SSLMODE"
echo ""
echo -e "${YELLOW}# Read-Write Connection (${CONN_NAME}_rw)${NC}"
echo "CONN_${CONN_NAME}_rw_HOST=$DB_HOST"
echo "CONN_${CONN_NAME}_rw_PORT=$DB_PORT"
echo "CONN_${CONN_NAME}_rw_DBNAME=$DB_NAME"
echo "CONN_${CONN_NAME}_rw_USER=mcp_readwrite"
echo "CONN_${CONN_NAME}_rw_PASSWORD=$READWRITE_PASS"
echo "CONN_${CONN_NAME}_rw_SSLMODE=$SSLMODE"
echo ""

# =============================================================================
# Offer to append to .env file
# =============================================================================

if [ -f ".env" ]; then
    echo ""
    read -p "Would you like to append this configuration to .env? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "" >> .env
        echo "# Connection: $CONN_NAME (Added $(date))" >> .env
        echo "# Read-Only Connection (${CONN_NAME}_ro)" >> .env
        echo "CONN_${CONN_NAME}_ro_HOST=$DB_HOST" >> .env
        echo "CONN_${CONN_NAME}_ro_PORT=$DB_PORT" >> .env
        echo "CONN_${CONN_NAME}_ro_DBNAME=$DB_NAME" >> .env
        echo "CONN_${CONN_NAME}_ro_USER=mcp_readonly" >> .env
        echo "CONN_${CONN_NAME}_ro_PASSWORD=$READONLY_PASS" >> .env
        echo "CONN_${CONN_NAME}_ro_SSLMODE=$SSLMODE" >> .env
        echo "" >> .env
        echo "# Read-Write Connection (${CONN_NAME}_rw)" >> .env
        echo "CONN_${CONN_NAME}_rw_HOST=$DB_HOST" >> .env
        echo "CONN_${CONN_NAME}_rw_PORT=$DB_PORT" >> .env
        echo "CONN_${CONN_NAME}_rw_DBNAME=$DB_NAME" >> .env
        echo "CONN_${CONN_NAME}_rw_USER=mcp_readwrite" >> .env
        echo "CONN_${CONN_NAME}_rw_PASSWORD=$READWRITE_PASS" >> .env
        echo "CONN_${CONN_NAME}_rw_SSLMODE=$SSLMODE" >> .env
        echo ""
        echo -e "${GREEN}✓ Configuration appended to .env${NC}"
    fi
fi

# =============================================================================
# Testing instructions
# =============================================================================

echo ""
echo -e "${BLUE}===============================================================================${NC}"
echo -e "${BLUE}Testing${NC}"
echo -e "${BLUE}===============================================================================${NC}"
echo ""
echo "Test the read-only role:"
echo -e "${CYAN}PGPASSWORD='$READONLY_PASS' psql -h $DB_HOST -p $DB_PORT -U mcp_readonly -d $DB_NAME -c 'SELECT version();'${NC}"
echo ""
echo "Test the read-write role:"
echo -e "${CYAN}PGPASSWORD='$READWRITE_PASS' psql -h $DB_HOST -p $DB_PORT -U mcp_readwrite -d $DB_NAME -c 'SELECT version();'${NC}"
echo ""
echo -e "${BLUE}===============================================================================${NC}"
echo ""
echo "Next steps:"
echo "1. Start your MCP server: docker compose up -d"
echo "2. Check health: curl http://localhost:8799/healthz"
echo "3. You should see connections: [\"${CONN_NAME}_ro\", \"${CONN_NAME}_rw\"]"
echo ""
