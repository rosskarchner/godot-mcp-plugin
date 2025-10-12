# Godot MCP Server Plugin

A complete Model Context Protocol (MCP) server implementation for Godot Engine 4.x that enables AI agents like Claude to directly inspect and manipulate the Godot editor and running games through HTTP.

## Features

- **HTTP-based MCP Server**: Robust HTTP server with JSON-RPC 2.0 protocol support
- **Scene Management**: Inspect scene trees, load/save scenes, navigate hierarchy
- **Node Operations**: Create, delete, rename nodes, modify properties in real-time
- **Script Management**: Attach/detach scripts, read source code, execute GDScript
- **Resource Access**: List project resources, read file contents
- **Visual Feedback**: Capture screenshots of the viewport
- **Scene Playback**: Start/stop scene playback programmatically
- **Editor Output**: Read editor logs including print() statements, errors, and warnings
- **CORS Support**: Built-in CORS headers for web-based clients
- **Configurable**: Editor settings for port, authentication, limits

## Installation

1. Copy the `addons/mcp_server/` directory into your Godot project's `addons/` folder
2. Open your project in Godot Editor
3. Go to **Project → Project Settings → Plugins**
4. Enable the "MCP Server" plugin
5. The server will start automatically on port 8765 (configurable)

## Configuration

The plugin adds settings under **Editor → Editor Settings → MCP Server**:

- **Port**: Server port (default: 8765)
- **Auto Start**: Start server when editor loads (default: true)
- **Auth Token**: Optional authentication token
- **Max Tree Depth**: Maximum depth for scene tree queries (default: 10)
- **Screenshot Max Width**: Maximum screenshot width (default: 1920)

## MCP Client Configuration

To connect an MCP client (like Claude Desktop) to this server, add the following to your MCP settings configuration:

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

For Claude Desktop, this file is typically located at:
- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
- **Linux**: `~/.config/Claude/claude_desktop_config.json`

## Available Tools

### Scene Management

#### `get_scene_tree`
Get the hierarchical structure of the current scene.

**Arguments:**
- `max_depth` (optional): Maximum depth to traverse (default: 10)

**Example:**
```json
{
  "name": "get_scene_tree",
  "arguments": {
    "max_depth": 5
  }
}
```

#### `get_current_scene`
Get information about the currently edited scene.

#### `save_scene`
Save the current scene to disk.

#### `load_scene`
Load a different scene for editing.

**Arguments:**
- `path`: Resource path to the scene file (e.g., `res://scenes/main.tscn`)

### Node Operations

#### `get_node_info`
Get detailed information about a specific node.

**Arguments:**
- `node_path`: Path to the node (e.g., `/root/Node2D/Player`)

#### `get_node_properties`
List all properties of a node with their current values.

**Arguments:**
- `node_path`: Path to the node

#### `set_node_property`
Set a property value on a specific node.

**Arguments:**
- `node_path`: Path to the node
- `property`: Property name (e.g., `position`, `rotation`)
- `value`: New value for the property

**Example:**
```json
{
  "name": "set_node_property",
  "arguments": {
    "node_path": "/root/Player",
    "property": "position",
    "value": [100, 200]
  }
}
```

#### `create_node`
Create a new node in the scene.

**Arguments:**
- `parent_path`: Path to the parent node
- `node_type`: Type of node to create (e.g., `Node2D`, `Sprite2D`)
- `node_name`: Name for the new node

#### `delete_node`
Delete a node from the scene.

**Arguments:**
- `node_path`: Path to the node to delete

#### `rename_node`
Rename a node.

**Arguments:**
- `node_path`: Path to the node
- `new_name`: New name for the node

### Script Operations

#### `get_node_script`
Get the script attached to a node.

**Arguments:**
- `node_path`: Path to the node

#### `set_node_script`
Attach or modify a script on a node.

**Arguments:**
- `node_path`: Path to the node
- `script_path`: Path to the script file (e.g., `res://scripts/player.gd`)

#### `get_script_source`
Read the source code of a script file.

**Arguments:**
- `script_path`: Path to the script file

#### `execute_gdscript`
Execute arbitrary GDScript code (limited for safety).

**Arguments:**
- `code`: GDScript code to execute

**⚠️ Security Warning**: This tool compiles and validates GDScript but does not execute arbitrary code for security reasons. Attach scripts to nodes for full execution.

### Resource Operations

#### `list_resources`
List resources in the project.

**Arguments:**
- `directory` (optional): Directory to list (default: `res://`)
- `filter` (optional): File extension filter (e.g., `.tscn`, `.gd`)

#### `get_screenshot`
Capture the current viewport as a base64-encoded PNG image.

#### `run_scene`
Start playing the current scene.

#### `stop_scene`
Stop the running scene.

### Editor Tools

#### `godot_editor_get_output`
Read recent output from the Godot editor's log file. This captures all `print()` statements, errors, warnings, and other output from the editor and running game.

**Arguments:**
- `max_lines` (optional): Maximum number of recent log lines to return (default: 100)
- `filter_text` (optional): Filter log lines containing specific text (case-insensitive)

**Example:**
```json
{
  "name": "godot_editor_get_output",
  "arguments": {
    "max_lines": 50,
    "filter_text": "error"
  }
}
```

**Use Cases:**
- Debug scripts by checking print() output
- Monitor errors and warnings during development
- Check game output after running a scene

## Protocol Implementation

The plugin implements MCP over JSON-RPC 2.0. All requests and responses follow the JSON-RPC 2.0 specification.

### Request Format

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "tool_name",
    "arguments": {
      "arg1": "value1"
    }
  },
  "id": 1
}
```

### Response Format

```json
{
  "jsonrpc": "2.0",
  "result": {
    "success": true,
    "data": "..."
  },
  "id": 1
}
```

### Error Format

```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32600,
    "message": "Invalid Request"
  },
  "id": 1
}
```

## Type Conversions

The plugin handles conversions between GDScript types and JSON:

- **Vector2/Vector3** ↔ Arrays: `[x, y]` or `[x, y, z]`
- **Color** ↔ Object: `{"r": 1.0, "g": 0.5, "b": 0.0, "a": 1.0}`
- **NodePath** ↔ String: `"/root/Node2D/Player"`
- **Resources** ↔ String paths: `"res://sprites/player.png"`

## Architecture

The plugin is structured into several modules:

```
addons/mcp_server/
├── plugin.cfg                  # Plugin metadata
├── mcp_server.gd              # Main EditorPlugin
├── http_handler.gd            # HTTP server and request handling
├── mcp_protocol.gd            # MCP/JSON-RPC 2.0 implementation
└── tools/                     # Tool implementations
    ├── scene_tools.gd         # Scene management
    ├── node_tools.gd          # Node operations
    ├── script_tools.gd        # Script operations
    └── resource_tools.gd      # Resource and utility tools
```

## Security Considerations

- The server listens on `127.0.0.1` (localhost only) by default
- Authentication token support is available (optional)
- Script execution is limited for security
- CORS headers allow web-based clients
- All operations are logged to the Godot console

**⚠️ Important**: Do not expose this server to the internet without proper authentication and security measures. It provides direct access to your Godot editor and project files.

## Troubleshooting

### Server won't start
- Check if the port is already in use
- Try changing the port in Editor Settings
- Check the Godot console for error messages

### Tools return "No scene is currently open"
- Make sure you have a scene open in the editor
- Try saving the scene first

### Node paths not working
- Use absolute paths from the scene root (e.g., `/root/Player`)
- Or use relative paths from the edited scene root
- Check node names are exact (case-sensitive)

### Screenshot returns error
- Ensure you have a viewport visible in the editor
- Try switching between 2D and 3D editor views

## Development

### Adding New Tools

1. Add the tool schema in `mcp_protocol.gd` → `_handle_tools_list()`
2. Add the tool handler in `mcp_protocol.gd` → `_handle_tools_call()`
3. Implement the tool function in the appropriate module under `tools/`

### Testing

Test the plugin manually by:
1. Enabling the plugin in a test project
2. Using curl or Postman to send requests
3. Connecting an MCP client like Claude Desktop

Example curl test:
```bash
curl -X POST http://localhost:8765 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "initialize",
    "params": {},
    "id": 1
  }'
```

## Requirements

- Godot Engine 4.0 or later
- Supports both 2D and 3D projects

## License

This plugin is provided as-is for use with Godot Engine projects.

## Contributing

Contributions are welcome! Please submit issues and pull requests on the GitHub repository.

## Acknowledgments

- Built for Godot Engine
- Implements the Model Context Protocol (MCP) specification
- Inspired by the need for AI-assisted game development
