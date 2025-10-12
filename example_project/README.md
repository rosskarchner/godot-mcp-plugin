# MCP Server Example Project

This is a minimal Godot project configured to use the MCP Server plugin.

## Setup

1. Open this project in Godot Engine 4.x
2. The MCP Server plugin should be automatically enabled
3. The server will start on port 8765 (check the Output console)

## Testing the Plugin

### Method 1: Using curl

Test the server with curl:

```bash
# Test initialization
curl -X POST http://localhost:8765 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "initialize",
    "params": {},
    "id": 1
  }'

# List available tools
curl -X POST http://localhost:8765 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/list",
    "params": {},
    "id": 2
  }'
```

### Method 2: Using Claude Desktop

1. Copy `../example_mcp_config.json` contents to your Claude Desktop configuration
2. Restart Claude Desktop
3. The Godot server should appear as an available tool
4. Try asking Claude to inspect your scene or create nodes

### Method 3: Create a Test Scene

1. Create a new scene in Godot (Scene → New Scene)
2. Add some nodes (e.g., Node2D → Sprite2D → Camera2D)
3. Save the scene as `res://scenes/test_scene.tscn`
4. Use the tools to query the scene tree:

```bash
curl -X POST http://localhost:8765 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "get_scene_tree",
      "arguments": {}
    },
    "id": 3
  }'
```

## Expected Behavior

When the plugin loads, you should see in the Output console:
```
MCP Server Plugin loaded
MCP Server started on port 8765
```

## Troubleshooting

If the server doesn't start:
- Check if port 8765 is already in use
- Try changing the port in Editor → Editor Settings → MCP Server → Port
- Check for errors in the Output console

## Creating Your Own Test Scenes

Feel free to create test scenes and experiment with the MCP tools:
- Create nodes and modify their properties
- Attach scripts to nodes
- Take screenshots
- Test scene playback

The plugin provides full access to the editor API through MCP tools.
