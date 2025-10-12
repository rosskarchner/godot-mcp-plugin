#!/bin/bash

# Test script for MCP Server

echo "Testing MCP Server on http://127.0.0.1:8765"
echo "=========================================="
echo ""

# Test 1: Initialize
echo "Test 1: Initialize Request"
echo "--------------------------"
curl -X POST http://127.0.0.1:8765 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "initialize",
    "params": {
      "protocolVersion": "2024-11-05",
      "capabilities": {},
      "clientInfo": {
        "name": "test-client",
        "version": "1.0.0"
      }
    },
    "id": 1
  }'
echo -e "\n"

# Test 2: List Tools
echo "Test 2: List Tools Request"
echo "--------------------------"
curl -X POST http://127.0.0.1:8765 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/list",
    "params": {},
    "id": 2
  }'
echo -e "\n"

# Test 3: Get Scene Tree
echo "Test 3: Get Scene Tree"
echo "----------------------"
curl -X POST http://127.0.0.1:8765 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "godot_scene_get_tree",
      "arguments": {}
    },
    "id": 3
  }'
echo -e "\n"

# Test 4: Get Current Scene
echo "Test 4: Get Current Scene"
echo "-------------------------"
curl -X POST http://127.0.0.1:8765 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "godot_scene_get_info",
      "arguments": {}
    },
    "id": 4
  }'
echo -e "\n"

echo "=========================================="
echo "Tests complete!"
