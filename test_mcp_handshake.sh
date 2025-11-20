#!/bin/bash
# Test MCP handshake sequence

echo "Testing MCP initialization handshake..."
echo ""

echo "1. Testing initialize request:"
INIT_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST http://127.0.0.1:8765 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc": "2.0", "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test-client", "version": "1.0.0"}}, "id": 1}')

HTTP_CODE=$(echo "$INIT_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$INIT_RESPONSE" | grep -v "HTTP_CODE:")

echo "   Status: $HTTP_CODE (expected: 200)"
echo "   Response:"
echo "$BODY" | python3 -m json.tool 2>/dev/null | head -20
echo ""

# Check ID type
ID_TYPE=$(echo "$BODY" | python3 -c "import json, sys; d=json.load(sys.stdin); print(type(d['id']).__name__)" 2>/dev/null)
echo "   ID type: $ID_TYPE (expected: int)"
echo ""

echo "2. Testing initialized notification:"
NOTIF_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST http://127.0.0.1:8765 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc": "2.0", "method": "initialized"}')

HTTP_CODE=$(echo "$NOTIF_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$NOTIF_RESPONSE" | grep -v "HTTP_CODE:")

echo "   Status: $HTTP_CODE (expected: 202)"
echo "   Body length: ${#BODY} (expected: 0)"
echo ""

echo "3. Testing tools/list:"
TOOLS_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST http://127.0.0.1:8765 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc": "2.0", "method": "tools/list", "id": 2}')

HTTP_CODE=$(echo "$TOOLS_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$TOOLS_RESPONSE" | grep -v "HTTP_CODE:")

echo "   Status: $HTTP_CODE (expected: 200)"
TOOL_COUNT=$(echo "$BODY" | python3 -c "import json, sys; d=json.load(sys.stdin); print(len(d['result']['tools']))" 2>/dev/null)
echo "   Number of tools: $TOOL_COUNT"
echo ""

if [ "$HTTP_CODE" = "200" ]; then
  echo "✓ All tests passed!"
else
  echo "✗ Some tests failed - check responses above"
fi
