# Godot MCP Server Plugin

A production-ready Godot Engine EditorPlugin that implements an HTTP transport MCP (Model Context Protocol) server. This plugin allows AI agents like Claude to directly inspect and manipulate the Godot editor and running games.

## Features

- ✅ **HTTP Server** - Built-in HTTP/1.1 server with JSON-RPC 2.0 support
- ✅ **MCP Protocol** - Full Model Context Protocol implementation
- ✅ **Scene Management** - Inspect, load, save, and traverse scene trees
- ✅ **Node Operations** - Create, delete, modify, and query nodes
- ✅ **Script Tools** - Read, attach, and execute GDScript code
- ✅ **Resource Management** - List and locate project resources
- ✅ **Security** - Optional authentication and configurable permissions
- ✅ **CORS Support** - Web-based client compatibility

## Installation

1. Copy the `addons/mcp_server/` folder into your Godot project's `addons` directory
2. Open your project in Godot Editor
3. Go to **Project → Project Settings → Plugins**
4. Find "MCP Server" in the list and check the "Enable" checkbox
5. The server will be ready to use (configure settings before starting)

## Quick Start

### Starting the Server

The plugin adds a menu item to the editor. You can also configure it to start automatically:

1. Go to **Editor → Editor Settings → MCP Server**
2. Configure your settings:
   - **Port**: Default is 8765
   - **Enable on Start**: Auto-start server when editor opens
   - **Auth Token**: Optional authentication (leave empty to disable)
   - **Allow Script Execution**: Enable `execute_gdscript` tool (⚠️ security risk)

### Test the Server

Once running, test with a simple HTTP request:

```bash
curl http://localhost:8765/health
```

You should see:
```json
{
  "status": "ok",
  "server": "Godot MCP Server",
  "version": "1.0.0"
}
```

## Configuration

### Editor Settings

All settings are found under **Editor → Editor Settings → MCP Server**:

| Setting | Default | Description |
|---------|---------|-------------|
| `network/port` | 8765 | HTTP server port |
| `network/enabled_on_start` | false | Auto-start server on editor launch |
| `security/auth_token` | "" | Optional authentication token |
| `security/allow_script_execution` | false | Enable `execute_gdscript` tool |
| `limits/max_tree_depth` | 10 | Maximum scene tree traversal depth |
| `limits/screenshot_max_size` | 1920 | Maximum screenshot dimension |

### Security Considerations

⚠️ **Important Security Notes:**

1. **Local Only**: The server binds to `127.0.0.1` (localhost) by default for security
2. **Authentication**: Set an auth token for additional protection
3. **Script Execution**: The `execute_gdscript` tool is **disabled by default** - only enable if you trust all clients
4. **Firewall**: Ensure your firewall blocks external access to the server port
5. **Development Only**: This plugin is intended for development environments, not production builds

## MCP Client Configuration

To connect an AI agent like Claude to your Godot editor, add this configuration to your MCP settings:

### Claude Desktop Configuration

Edit your Claude Desktop configuration file:

**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
**Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
**Linux**: `~/.config/Claude/claude_desktop_config.json`

Add the following:

```json
{
  "mcpServers": {
    "godot": {
      "url": "http://localhost:8765",
      "transport": {
        "type": "http"
      }
    }
  }
}
```

If you enabled authentication, include the token:

```json
{
  "mcpServers": {
    "godot": {
      "url": "http://localhost:8765",
      "transport": {
        "type": "http"
      },
      "auth": {
        "type": "bearer",
        "token": "your_secret_token_here"
      }
    }
  }
}
```

## Available Tools

### Scene Management

#### `get_scene_tree`
Get the hierarchical structure of the current scene.

**Parameters:**
- `max_depth` (optional): Maximum depth to traverse

**Example:**
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "get_scene_tree",
    "arguments": {
      "max_depth": 5
    }
  },
  "id": 1
}
```

#### `get_current_scene`
Get information about the currently edited scene.

#### `save_scene`
Save the current scene to disk.

#### `load_scene`
Load a different scene.

**Parameters:**
- `path` (required): Scene file path (e.g., `"res://scenes/level.tscn"`)

### Node Operations

#### `get_node_info`
Get detailed information about a specific node.

**Parameters:**
- `node_path` (required): Path to the node (e.g., `"Player"` or `"Level/Enemy"`)

#### `get_node_properties`
List all properties of a node with their current values.

**Parameters:**
- `node_path` (required): Path to the node

#### `set_node_property`
Set a property value on a specific node.

**Parameters:**
- `node_path` (required): Path to the node
- `property` (required): Property name (e.g., `"position"`, `"rotation"`)
- `value` (required): New value

**Example:**
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "set_node_property",
    "arguments": {
      "node_path": "Player",
      "property": "position",
      "value": [100, 200]
    }
  },
  "id": 2
}
```

#### `create_node`
Create a new node in the scene.

**Parameters:**
- `type` (required): Node type (e.g., `"Node2D"`, `"Sprite2D"`)
- `name` (required): Name for the new node
- `parent_path` (optional): Parent node path

#### `delete_node`
Delete a node from the scene.

**Parameters:**
- `node_path` (required): Path to the node to delete

#### `rename_node`
Rename a node.

**Parameters:**
- `node_path` (required): Path to the node
- `new_name` (required): New name

#### `move_node`
Move a node to a different parent.

**Parameters:**
- `node_path` (required): Path to the node to move
- `new_parent_path` (required): Path to the new parent

### Script Operations

#### `get_node_script`
Get the script attached to a node.

**Parameters:**
- `node_path` (required): Path to the node

#### `set_node_script`
Attach or modify a script on a node.

**Parameters:**
- `node_path` (required): Path to the node
- `script_path` (required): Path to the script file (empty to remove)

#### `get_script_source`
Read the source code of a script file.

**Parameters:**
- `script_path` (required): Path to the script file

#### `list_script_methods`
List methods defined in a script.

**Parameters:**
- `script_path` (required): Path to the script file

#### `execute_gdscript` (⚠️ Requires `allow_script_execution`)
Execute arbitrary GDScript code.

**Parameters:**
- `code` (required): GDScript code to execute

**Example:**
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "execute_gdscript",
    "arguments": {
      "code": "print('Hello from MCP!')\nreturn 2 + 2"
    }
  },
  "id": 3
}
```

### Resource Operations

#### `list_resources`
List resources in the project.

**Parameters:**
- `type_filter` (optional): Filter by extension (e.g., `"tscn"`, `"gd"`, `"png"`)
- `path` (optional): Directory path to search (default: `"res://"`)

#### `get_resource_path`
Get filesystem path for a resource by name.

**Parameters:**
- `resource_name` (required): Name of the resource

## Protocol Details

### JSON-RPC 2.0 Format

All requests must follow JSON-RPC 2.0:

```json
{
  "jsonrpc": "2.0",
  "method": "method_name",
  "params": { },
  "id": 1
}
```

Successful responses:
```json
{
  "jsonrpc": "2.0",
  "result": { },
  "id": 1
}
```

Error responses:
```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32600,
    "message": "Error description"
  },
  "id": 1
}
```

### Core MCP Methods

#### `initialize`
Initialize the MCP connection and exchange capabilities.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "initialize",
  "params": {
    "protocolVersion": "2024-11-05",
    "clientInfo": {
      "name": "client-name",
      "version": "1.0.0"
    }
  },
  "id": 1
}
```

#### `tools/list`
List all available tools.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "tools/list",
  "params": {},
  "id": 2
}
```

#### `tools/call`
Execute a specific tool.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "tool_name",
    "arguments": { }
  },
  "id": 3
}
```

## Type Conversions

The plugin handles conversions between GDScript types and JSON:

| GDScript Type | JSON Format | Example |
|---------------|-------------|---------|
| `Vector2(10, 20)` | Array `[10, 20]` | `"value": [10, 20]` |
| `Vector3(1, 2, 3)` | Array `[1, 2, 3]` | `"value": [1, 2, 3]` |
| `Color(1, 0, 0, 1)` | String or Array | `"value": "#ff0000"` or `[1, 0, 0, 1]` |
| `NodePath` | String | `"value": "/root/Player"` |

## Troubleshooting

### Server Won't Start

1. **Port already in use**: Change the port in editor settings
2. **Permission denied**: Try a different port (> 1024)
3. **Check the Output panel** in Godot for error messages

### Connection Refused

1. Ensure the server is running (check Output panel for "Started on port...")
2. Verify you're connecting to `localhost` or `127.0.0.1`
3. Check firewall settings

### Tool Execution Fails

1. **Node not found**: Verify the node path is correct (relative to scene root)
2. **Property not found**: Check the property name matches exactly (case-sensitive)
3. **Script execution disabled**: Enable `allow_script_execution` in settings
4. **Authentication failed**: Ensure you're sending the correct auth token

### Scene Not Updating

1. Changes are applied immediately but may require editor refresh
2. Use `save_scene` to persist changes
3. Check if the scene is marked as modified (asterisk in tab)

## Development

### Project Structure

```
addons/mcp_server/
├── plugin.cfg              # Plugin metadata
├── mcp_server.gd          # Main EditorPlugin
├── http_handler.gd        # HTTP server implementation
├── mcp_protocol.gd        # MCP/JSON-RPC protocol handler
└── tools/                 # Tool implementations
    ├── scene_tools.gd     # Scene management
    ├── node_tools.gd      # Node operations
    ├── script_tools.gd    # Script tools
    └── resource_tools.gd  # Resource management
```

### Adding Custom Tools

To add a new tool:

1. Add the tool implementation to the appropriate file in `tools/`
2. Add the tool schema in `mcp_protocol.gd` → `_handle_tools_list()`
3. Route the tool call in `mcp_protocol.gd` → `_handle_tool_call()`

Example:
```gdscript
func my_custom_tool(arg1: String) -> Dictionary:
    # Your implementation
    return {
        "success": true,
        "result": "something"
    }
```

## Compatibility

- **Godot Version**: 4.0+ (tested on Godot 4.3)
- **Platform**: Windows, macOS, Linux
- **Transport**: HTTP only (WebSocket support planned)

## License

This plugin is provided as-is for development purposes. Use at your own risk.

## Contributing

Contributions are welcome! Areas for improvement:

- [ ] WebSocket transport support
- [ ] Screenshot capture tool
- [ ] Run/stop scene tools
- [ ] Debugger integration
- [ ] Performance optimization
- [ ] Unit tests

## Support

For issues, questions, or feature requests, please open an issue on the project repository.

---

**⚠️ Security Warning**: This plugin allows remote code execution when script execution is enabled. Only use in trusted development environments. Never expose the server to public networks.
