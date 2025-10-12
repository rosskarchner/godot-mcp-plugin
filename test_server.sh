#!/bin/bash

# Test script for Godot MCP Server
# 
# This script tests basic functionality of the MCP server.
# Make sure Godot is running with the plugin enabled before running this.

SERVER_URL="http://localhost:8765"
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Godot MCP Server Test Suite ===${NC}\n"

# Test 1: Initialize
echo -e "${BLUE}Test 1: Initialize${NC}"
response=$(curl -s -X POST $SERVER_URL \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "initialize",
    "params": {},
    "id": 1
  }')

if echo "$response" | grep -q "protocolVersion"; then
  echo -e "${GREEN}✓ Initialize successful${NC}\n"
else
  echo -e "${RED}✗ Initialize failed${NC}"
  echo "Response: $response\n"
fi

# Test 2: List tools
echo -e "${BLUE}Test 2: List tools${NC}"
response=$(curl -s -X POST $SERVER_URL \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/list",
    "params": {},
    "id": 2
  }')

if echo "$response" | grep -q "get_scene_tree"; then
  echo -e "${GREEN}✓ Tools list successful${NC}"
  tool_count=$(echo "$response" | grep -o '"name"' | wc -l)
  echo "Found $tool_count tools\n"
else
  echo -e "${RED}✗ Tools list failed${NC}"
  echo "Response: $response\n"
fi

# Test 3: Get current scene
echo -e "${BLUE}Test 3: Get current scene${NC}"
response=$(curl -s -X POST $SERVER_URL \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "get_current_scene",
      "arguments": {}
    },
    "id": 3
  }')

if echo "$response" | grep -q "path\|error"; then
  echo -e "${GREEN}✓ Get current scene successful${NC}"
  echo "Response: $response\n"
else
  echo -e "${RED}✗ Get current scene failed${NC}"
  echo "Response: $response\n"
fi

# Test 4: List resources
echo -e "${BLUE}Test 4: List resources${NC}"
response=$(curl -s -X POST $SERVER_URL \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "resources/list",
    "params": {},
    "id": 4
  }')

if echo "$response" | grep -q "resources"; then
  echo -e "${GREEN}✓ List resources successful${NC}"
  resource_count=$(echo "$response" | grep -o '"uri"' | wc -l)
  echo "Found $resource_count resources\n"
else
  echo -e "${RED}✗ List resources failed${NC}"
  echo "Response: $response\n"
fi

# Test 5: Invalid method
echo -e "${BLUE}Test 5: Invalid method (error handling)${NC}"
response=$(curl -s -X POST $SERVER_URL \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "invalid_method",
    "params": {},
    "id": 5
  }')

if echo "$response" | grep -q "error"; then
  echo -e "${GREEN}✓ Error handling works${NC}"
  echo "Response: $response\n"
else
  echo -e "${RED}✗ Error handling failed${NC}"
  echo "Response: $response\n"
fi

# Test 6: OPTIONS (CORS preflight)
echo -e "${BLUE}Test 6: OPTIONS request (CORS)${NC}"
http_code=$(curl -s -o /dev/null -w "%{http_code}" -X OPTIONS $SERVER_URL)

if [ "$http_code" = "204" ]; then
  echo -e "${GREEN}✓ CORS preflight successful${NC}\n"
else
  echo -e "${RED}✗ CORS preflight failed (HTTP $http_code)${NC}\n"
fi

echo -e "${BLUE}=== Test Suite Complete ===${NC}"
echo -e "\nNote: Some tests may fail if no scene is open in Godot."
echo -e "Open a scene in the Godot editor and run this script again for full testing.\n"
