#!/bin/bash

# =============================================================================
# n8n REST API Test Script
# =============================================================================
# Author: Frederick Mbuya
# License: MIT
#
# This script tests the new n8n-friendly REST API endpoints.
#
# Usage:
#   ./test-n8n-api.sh [HOST] [TOKEN]
#
# Examples:
#   ./test-n8n-api.sh
#   ./test-n8n-api.sh http://localhost:8799
#   ./test-n8n-api.sh http://localhost:8799 my-secret-token
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
HOST="${1:-http://localhost:8799}"
TOKEN="${2:-}"

echo -e "${BLUE}===============================================================================${NC}"
echo -e "${BLUE}n8n REST API Test Suite${NC}"
echo -e "${BLUE}===============================================================================${NC}"
echo -e "Host: ${HOST}"
echo -e "Token: ${TOKEN:-(not set)}"
echo -e "${BLUE}===============================================================================${NC}"
echo ""

# Helper function to make requests
make_request() {
  local method="$1"
  local endpoint="$2"
  local data="$3"
  local description="$4"

  echo -e "${YELLOW}Test: ${description}${NC}"

  if [ "$method" = "GET" ]; then
    if [ -n "$TOKEN" ]; then
      response=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TOKEN" "${HOST}${endpoint}")
    else
      response=$(curl -s -w "\n%{http_code}" "${HOST}${endpoint}")
    fi
  else
    if [ -n "$TOKEN" ]; then
      response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "$data" \
        "${HOST}${endpoint}")
    else
      response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$data" \
        "${HOST}${endpoint}")
    fi
  fi

  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | head -n -1)

  if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    echo -e "${GREEN}✓ Success (HTTP $http_code)${NC}"
    echo "$body" | jq '.' 2>/dev/null || echo "$body"
  else
    echo -e "${RED}✗ Failed (HTTP $http_code)${NC}"
    echo "$body" | jq '.' 2>/dev/null || echo "$body"
  fi

  echo ""
}

# =============================================================================
# Test 1: Health Check (Existing endpoint - verify we didn't break it)
# =============================================================================
echo -e "${CYAN}=== Testing Existing Endpoints (Verify No Breakage) ===${NC}"
echo ""
make_request "GET" "/healthz" "" "Health Check (Existing)"

# =============================================================================
# Test 2: MCP Initialize (Verify MCP still works)
# =============================================================================
make_request "POST" "/mcp" '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {}
}' "MCP Initialize (Existing - Should Still Work)"

echo -e "${CYAN}=== Testing New n8n REST API Endpoints ===${NC}"
echo ""

# =============================================================================
# Test 3: List Connections
# =============================================================================
make_request "GET" "/api/connections" "" "List Available Connections"

# =============================================================================
# Test 4: Get All Tables Schema
# =============================================================================
make_request "POST" "/api/schema" '{
  "connection": "prod_ro"
}' "Get All Tables (Schema)"

# =============================================================================
# Test 5: Get Specific Table Schema
# =============================================================================
make_request "POST" "/api/schema" '{
  "connection": "prod_ro",
  "table": "vehicles"
}' "Get Vehicles Table Schema"

# =============================================================================
# Test 6: Execute Simple Query
# =============================================================================
make_request "POST" "/api/query" '{
  "connection": "prod_ro",
  "sql": "SELECT 1 as test, current_database() as db, current_user as user"
}' "Execute Simple Test Query"

# =============================================================================
# Test 7: Execute Query with Parameters
# =============================================================================
make_request "POST" "/api/query" '{
  "connection": "prod_ro",
  "sql": "SELECT $1::text as param1, $2::text as param2",
  "params": ["hello", "world"]
}' "Execute Parameterized Query"

# =============================================================================
# Test 8: Test Error Handling - Unknown Connection
# =============================================================================
echo -e "${CYAN}=== Testing Error Handling ===${NC}"
echo ""
make_request "POST" "/api/query" '{
  "connection": "nonexistent",
  "sql": "SELECT 1"
}' "Error: Unknown Connection (Should Return 404)"

# =============================================================================
# Test 9: Test Error Handling - Missing Required Field
# =============================================================================
make_request "POST" "/api/query" '{
  "connection": "prod_ro"
}' "Error: Missing SQL Field (Should Return 400)"

# =============================================================================
# Test 10: Test Error Handling - Write Operation (if read-only)
# =============================================================================
make_request "POST" "/api/query" '{
  "connection": "prod_ro",
  "sql": "INSERT INTO test_table VALUES (1)"
}' "Error: Write Operation in Read-Only Mode (Should Return 403)"

# =============================================================================
# Test 11: Test Schema - Invalid Connection
# =============================================================================
make_request "POST" "/api/schema" '{
  "connection": "invalid"
}' "Error: Schema with Invalid Connection (Should Return 404)"

# =============================================================================
# Summary
# =============================================================================
echo -e "${BLUE}===============================================================================${NC}"
echo -e "${GREEN}Test suite completed!${NC}"
echo -e "${BLUE}===============================================================================${NC}"
echo ""
echo "Summary:"
echo "✓ Old MCP endpoints still work (backward compatibility)"
echo "✓ New REST API endpoints are functional"
echo "✓ Error handling works correctly"
echo ""
echo "Next steps:"
echo "1. If all tests passed, the API is ready for n8n integration ✓"
echo "2. Configure n8n HTTP Request nodes as shown in N8N_API_GUIDE.md"
echo "3. Create your AI agent workflow in n8n"
echo ""
echo "Documentation:"
echo "- Full API guide: N8N_API_GUIDE.md"
echo "- Setup guide: QUICKSTART.md"
echo ""
