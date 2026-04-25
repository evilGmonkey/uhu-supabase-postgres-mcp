#!/bin/bash

# =============================================================================
# Interactive MCP Role Setup Script
# =============================================================================
# Author: Frederick Mbuya
# License: MIT
#
# This script interactively creates both mcp_readonly and mcp_readwrite roles
# and outputs the connection configuration for your .env file.
#
# Usage:
#   ./setup-mcp-roles.sh       - Create/update roles (default)
#   ./setup-mcp-roles.sh -c    - Check roles existence and permissions only
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Parse command line flags
CHECK_ONLY=false
SKIP_ENV=false
DB_HOST=""
DB_PORT=""
DB_NAME=""
ADMIN_USER=""
ADMIN_PASSWORD=""
READONLY_PASS=""
READWRITE_PASS=""

while getopts "cnh:p:d:u:P:r:w:" opt; do
    case $opt in
        c)
            CHECK_ONLY=true
            ;;
        n)
            SKIP_ENV=true
            ;;
        h)
            DB_HOST="$OPTARG"
            ;;
        p)
            DB_PORT="$OPTARG"
            ;;
        d)
            DB_NAME="$OPTARG"
            ;;
        u)
            ADMIN_USER="$OPTARG"
            ;;
        P)
            ADMIN_PASSWORD="$OPTARG"
            ;;
        r)
            READONLY_PASS="$OPTARG"
            ;;
        w)
            READWRITE_PASS="$OPTARG"
            ;;
        \?)
            echo "Usage: $0 [-c] [-n] [-h host] [-p port] [-d database] [-u username] [-P password] [-r readonly_pass] [-w readwrite_pass]"
            echo "  -c    Check roles existence and permissions only (no modifications)"
            echo "  -n    Skip .env file generation (only create/update roles)"
            echo "  -h    PostgreSQL host (default: localhost)"
            echo "  -p    PostgreSQL port (default: 5432)"
            echo "  -d    Database name (default: postgres)"
            echo "  -u    Admin username (default: postgres)"
            echo "  -P    Admin password (will prompt if not provided)"
            echo "  -r    mcp_readonly password (auto-generated if not provided)"
            echo "  -w    mcp_readwrite password (auto-generated if not provided)"
            exit 1
            ;;
    esac
done

if [ "$CHECK_ONLY" = true ]; then
    echo -e "${BLUE}===============================================================================${NC}"
    echo -e "${BLUE}MCP Database Role Check (Read-Only Mode)${NC}"
    echo -e "${BLUE}===============================================================================${NC}"
else
    echo -e "${BLUE}===============================================================================${NC}"
    echo -e "${BLUE}MCP Database Role Setup${NC}"
    echo -e "${BLUE}===============================================================================${NC}"
fi
echo ""

# =============================================================================
# Prompt for database connection details
# =============================================================================

echo -e "${CYAN}Step 1: Database Connection Information${NC}"
echo ""

# Prompt for DB_HOST if not provided via flag
if [ -z "$DB_HOST" ]; then
    read -p "PostgreSQL Host [localhost]: " DB_HOST
    DB_HOST=${DB_HOST:-localhost}
fi

# Prompt for DB_PORT if not provided via flag
if [ -z "$DB_PORT" ]; then
    read -p "PostgreSQL Port [5432]: " DB_PORT
    DB_PORT=${DB_PORT:-5432}
fi

# Prompt for DB_NAME if not provided via flag
if [ -z "$DB_NAME" ]; then
    read -p "Database Name [postgres]: " DB_NAME
    DB_NAME=${DB_NAME:-postgres}
fi

# Prompt for ADMIN_USER if not provided via flag
if [ -z "$ADMIN_USER" ]; then
    read -p "Admin Username [postgres]: " ADMIN_USER
    ADMIN_USER=${ADMIN_USER:-postgres}
fi

# Prompt for ADMIN_PASSWORD if not provided via flag
if [ -z "$ADMIN_PASSWORD" ]; then
    echo -n "Admin Password: "
    read -s ADMIN_PASSWORD
    echo ""
fi

if [ -z "$ADMIN_PASSWORD" ]; then
    echo -e "${RED}Error: Admin password cannot be empty${NC}"
    exit 1
fi

echo ""

# =============================================================================
# Prompt for connection name (skip if check-only mode)
# =============================================================================

if [ "$CHECK_ONLY" = false ]; then
    # Only prompt for connection name if not skipping .env
    if [ "$SKIP_ENV" = false ]; then
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
    fi

    # =============================================================================
    # Generate strong passwords for MCP roles (if not provided via flags)
    # =============================================================================

    if [ "$SKIP_ENV" = false ]; then
        echo -e "${CYAN}Step 3: Generating secure passwords for MCP roles...${NC}"
    else
        echo -e "${CYAN}Step 2: Setting up passwords for MCP roles...${NC}"
    fi
    echo ""

    if [ -z "$READONLY_PASS" ]; then
        READONLY_PASS=$(openssl rand -base64 32)
        echo -e "${GREEN}✓ Generated read-only password${NC}"
    else
        echo -e "${GREEN}✓ Using provided read-only password${NC}"
    fi

    if [ -z "$READWRITE_PASS" ]; then
        READWRITE_PASS=$(openssl rand -base64 32)
        echo -e "${GREEN}✓ Generated read-write password${NC}"
    else
        echo -e "${GREEN}✓ Using provided read-write password${NC}"
    fi

    echo ""
fi

# =============================================================================
# Test database connection
# =============================================================================

if [ "$CHECK_ONLY" = false ]; then
    if [ "$SKIP_ENV" = false ]; then
        STEP_NUM=4
    else
        STEP_NUM=3
    fi
else
    STEP_NUM=2
fi

echo -e "${CYAN}Step ${STEP_NUM}: Testing database connection...${NC}"
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
# Check roles (if -c flag) or Create roles
# =============================================================================

if [ "$CHECK_ONLY" = true ]; then
    echo -e "${CYAN}Step 3: Checking MCP roles...${NC}"
    echo ""

    CHECK_RESULT=$(PGPASSWORD="$ADMIN_PASSWORD" psql \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$ADMIN_USER" \
        -d "$DB_NAME" \
        -t -A \
        << 'EOF'
-- Check if roles exist
SELECT
    CASE
        WHEN EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mcp_readonly') THEN 'exists'
        ELSE 'missing'
    END as readonly_status,
    CASE
        WHEN EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mcp_readwrite') THEN 'exists'
        ELSE 'missing'
    END as readwrite_status;

-- Check mcp_readonly permissions on public schema
SELECT
    'mcp_readonly' as role,
    has_schema_privilege('mcp_readonly', 'public', 'USAGE') as has_usage,
    has_database_privilege('mcp_readonly', current_database(), 'CONNECT') as has_connect;

-- Check mcp_readwrite permissions on public schema
SELECT
    'mcp_readwrite' as role,
    has_schema_privilege('mcp_readwrite', 'public', 'USAGE') as has_usage,
    has_database_privilege('mcp_readwrite', current_database(), 'CONNECT') as has_connect;

-- Check table-level permissions for a sample table (if any exist)
SELECT
    'mcp_readonly' as role,
    tablename,
    has_table_privilege('mcp_readonly', schemaname||'.'||tablename, 'SELECT') as can_select
FROM pg_tables
WHERE schemaname = 'public'
LIMIT 1;

SELECT
    'mcp_readwrite' as role,
    tablename,
    has_table_privilege('mcp_readwrite', schemaname||'.'||tablename, 'SELECT') as can_select,
    has_table_privilege('mcp_readwrite', schemaname||'.'||tablename, 'INSERT') as can_insert,
    has_table_privilege('mcp_readwrite', schemaname||'.'||tablename, 'UPDATE') as can_update,
    has_table_privilege('mcp_readwrite', schemaname||'.'||tablename, 'DELETE') as can_delete
FROM pg_tables
WHERE schemaname = 'public'
LIMIT 1;
EOF
)

    # Parse and display results
    echo "$CHECK_RESULT" | while IFS='|' read -r line; do
        echo "$line"
    done

    echo ""

    # Check role existence
    READONLY_EXISTS=$(PGPASSWORD="$ADMIN_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$ADMIN_USER" -d "$DB_NAME" -t -A -c "SELECT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mcp_readonly');")
    READWRITE_EXISTS=$(PGPASSWORD="$ADMIN_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$ADMIN_USER" -d "$DB_NAME" -t -A -c "SELECT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mcp_readwrite');")

    if [ "$READONLY_EXISTS" = "t" ]; then
        echo -e "${GREEN}✓ Role 'mcp_readonly' exists${NC}"
    else
        echo -e "${RED}✗ Role 'mcp_readonly' does not exist${NC}"
    fi

    if [ "$READWRITE_EXISTS" = "t" ]; then
        echo -e "${GREEN}✓ Role 'mcp_readwrite' exists${NC}"
    else
        echo -e "${RED}✗ Role 'mcp_readwrite' does not exist${NC}"
    fi

    echo ""
    echo -e "${BLUE}===============================================================================${NC}"
    echo -e "${BLUE}Check Complete${NC}"
    echo -e "${BLUE}===============================================================================${NC}"
    echo ""

    if [ "$READONLY_EXISTS" = "t" ] && [ "$READWRITE_EXISTS" = "t" ]; then
        echo -e "${GREEN}Both roles exist. Review permissions above.${NC}"
        exit 0
    else
        echo -e "${YELLOW}One or more roles are missing. Run without -c flag to create them.${NC}"
        exit 1
    fi
fi

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
# Output configuration for .env file (skip if -n flag)
# =============================================================================

if [ "$SKIP_ENV" = false ]; then
    # Determine SSL mode
    if [ "$DB_HOST" = "localhost" ] || [ "$DB_HOST" = "127.0.0.1" ]; then
        SSLMODE="prefer"
    else
        SSLMODE="require"
    fi

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

    # Offer to append to .env file
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
else
    # Skip .env mode - just confirm roles created
    echo -e "${BLUE}===============================================================================${NC}"
    echo -e "${BLUE}Roles Created Successfully!${NC}"
    echo -e "${BLUE}===============================================================================${NC}"
    echo ""
    echo -e "${GREEN}✓ Roles 'mcp_readonly' and 'mcp_readwrite' have been created/updated${NC}"
    echo ""
    echo "Credentials:"
    echo "  mcp_readonly password: $READONLY_PASS"
    echo "  mcp_readwrite password: $READWRITE_PASS"
    echo ""
fi

# =============================================================================
# Testing instructions (skip if -n flag)
# =============================================================================

if [ "$SKIP_ENV" = false ]; then
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
fi
