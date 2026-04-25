#!/bin/bash

# =============================================================================
# MCP Server Test Script
# =============================================================================
# Author: Frederick Mbuya
# License: MIT
#
# This script tests the MCP server endpoints to verify everything is working.
#
# Usage:
#   ./test-server.sh [HOST] [TOKEN]
#
# Examples:
#   ./test-server.sh
#   ./test-server.sh http://localhost:8799
#   ./test-server.sh http://localhost:8799 my-secret-token
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
HOST="${1:-http://localhost:8799}"
TOKEN="${2:-}"
MCP_PATH="/mcp"

echo -e "${BLUE}===============================================================================${NC}"
echo -e "${BLUE}MCP Server Test Suite${NC}"
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
    echo "$body"
  fi

  echo ""
}

# =============================================================================
# Test 1: Health Check
# =============================================================================
make_request "GET" "/healthz" "" "Health Check"

# =============================================================================
# Test 2: Initialize
# =============================================================================
make_request "POST" "$MCP_PATH" '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {}
}' "MCP Initialize"

# =============================================================================
# Test 3: Server Info
# =============================================================================
make_request "POST" "$MCP_PATH" '{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "server/info"
}' "Server Info"

# =============================================================================
# Test 4: List Tools
# =============================================================================
make_request "POST" "$MCP_PATH" '{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/list"
}' "List Tools"

# =============================================================================
# Test 5: List Prompts
# =============================================================================
make_request "POST" "$MCP_PATH" '{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "prompts/list"
}' "List Prompts"

# =============================================================================
# Test 6: List Resources
# =============================================================================
make_request "POST" "$MCP_PATH" '{
  "jsonrpc": "2.0",
  "id": 5,
  "method": "resources/list"
}' "List Resources"

# =============================================================================
# Test 7: Test SQL Query (if connection name provided)
# =============================================================================
if [ -n "$3" ]; then
  CONNECTION_NAME="$3"
  echo -e "${YELLOW}Test: SQL Query (connection: $CONNECTION_NAME)${NC}"

  make_request "POST" "$MCP_PATH" "{
    \"jsonrpc\": \"2.0\",
    \"id\": 6,
    \"method\": \"tools/call\",
    \"params\": {
      \"name\": \"sql.query\",
      \"arguments\": {
        \"connection\": \"$CONNECTION_NAME\",
        \"sql\": \"SELECT 1 as test, current_database() as db, current_user as user\"
      }
    }
  }" "SQL Query Test"
fi

# =============================================================================
# Summary
# =============================================================================
echo -e "${BLUE}===============================================================================${NC}"
echo -e "${GREEN}Test suite completed!${NC}"
echo -e "${BLUE}===============================================================================${NC}"
echo ""
echo "Next steps:"
echo "1. If health check passed, server is running ✓"
echo "2. If tools/list passed, MCP protocol is working ✓"
echo "3. To test SQL queries, run:"
echo "   ./test-server.sh $HOST $TOKEN <connection-name>"
echo ""
echo "Example:"
echo "   ./test-server.sh http://localhost:8799 my-token prod"
echo ""
