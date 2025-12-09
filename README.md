The features of this plugin have been rolled into https://github.com/rosskarchner/godot-mcp

# Godot MCP Server Plugin

A complete Model Context Protocol (MCP) server implementation for Godot Engine 4.x that enables AI agents like Claude to directly inspect and manipulate the Godot editor and running games through HTTP.

## Features

- **HTTP-based MCP Server**: Robust HTTP server with JSON-RPC 2.0 protocol support
- **Scene Management**: Inspect scene trees, load/save scenes, navigate hierarchy
- **Node Operations**: Create, delete, rename nodes, modify properties in real-time
- **Script Management**: Attach/detach scripts, read source code, execute GDScript
- **Resource Access**: List project resources, read file contents
- **Project Configuration**: Get/set project settings from project.godot
- **Input Management**: Configure input maps, actions, and key bindings
- **Input Simulation**: Send simulated keyboard, mouse, and gamepad events to running games
- **Visual Feedback**: Capture screenshots of the viewport with configurable resolution and region cropping
- **Scene Playback**: Start/stop scene playback programmatically
- **Editor Output**: Read editor logs including print() statements, errors, and warnings
- **CORS Support**: Built-in CORS headers for web-based clients
- **Configurable**: Editor settings for port, authentication, limits

## Quick Start

The easiest way to get started is with the included example project:

```bash
# From the repository root:
./setup_example.sh
# Then open ./example_project in Godot Engine
```

The example project comes with the plugin pre-configured and ready to use.

## Installation

For your own projects:

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

### Resource Operations

#### `list_resources`
List resources in the project.

**Arguments:**
- `directory` (optional): Directory to list (default: `res://`)
- `filter` (optional): File extension filter (e.g., `.tscn`, `.gd`)

#### `get_screenshot`
Capture the current viewport as a base64-encoded PNG image. Default resolution (1280x720) is optimized to stay under 25,000 tokens. Supports custom resolution limits and region cropping.

**Arguments:**
- `max_width` (optional): Maximum width in pixels (default: 1280)
- `max_height` (optional): Maximum height in pixels (default: 720)
- `region_x`, `region_y`, `region_width`, `region_height` (optional): Capture specific viewport region

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

### Project Configuration

#### `godot_project_get_setting`
Get the value of a project setting from project.godot.

**Arguments:**
- `setting_name`: Full path to the setting (e.g., `application/config/name`)

#### `godot_project_set_setting`
Set a project setting value in project.godot.

**Arguments:**
- `setting_name`: Full path to the setting
- `value`: New value (supports Godot types like Vector2, Color)

#### `godot_project_list_settings`
List all project settings or filter by prefix.

**Arguments:**
- `prefix` (optional): Category prefix to filter (e.g., `application/`, `display/`)

### Input Map Management

#### `godot_input_list_actions`
List all input actions and their key/button bindings.

#### `godot_input_get_action`
Get detailed information about a specific input action.

**Arguments:**
- `action_name`: Name of the input action (e.g., `ui_accept`, `jump`)

#### `godot_input_add_action`
Create a new input action.

**Arguments:**
- `action_name`: Name for the new action
- `deadzone` (optional): Deadzone for analog inputs (default: 0.5)

#### `godot_input_remove_action`
Delete an input action.

**Arguments:**
- `action_name`: Name of the action to remove

#### `godot_input_add_event`
Add a key, mouse button, or joypad event to an action.

**Arguments:**
- `action_name`: Target action name
- `event`: Event specification (e.g., `{"type": "key", "keycode": 32, "pressed": true}`)

**Example:**
```json
{
  "name": "godot_input_add_event",
  "arguments": {
    "action_name": "jump",
    "event": {
      "type": "key",
      "keycode": 32,
      "pressed": true
    }
  }
}
```

#### `godot_input_remove_event`
Remove a specific input event from an action.

### Input Event Simulation

#### `godot_input_send_action`
Send a simulated input action event to the running game.

**Arguments:**
- `action_name`: Action to trigger
- `pressed` (optional): Whether pressed (true) or released (false)
- `strength` (optional): Input strength 0.0-1.0

#### `godot_input_send_key`
Send a keyboard key press/release event.

**Arguments:**
- `keycode`: Key code (use `godot_input_get_constants` for values)
- `pressed` (optional): Whether pressed (default: true)
- `alt_pressed`, `shift_pressed`, `ctrl_pressed`, `meta_pressed` (optional): Modifier keys

#### `godot_input_send_mouse_button`
Send a mouse button event.

**Arguments:**
- `button_index`: Mouse button (1=Left, 2=Right, 3=Middle)
- `pressed` (optional): Whether pressed
- `position_x`, `position_y` (optional): Screen position
- `double_click` (optional): Whether double-click

#### `godot_input_send_mouse_motion`
Send a mouse motion event.

**Arguments:**
- `position_x`, `position_y`: Mouse position
- `relative_x`, `relative_y` (optional): Relative movement
- `velocity_x`, `velocity_y` (optional): Movement velocity

#### `godot_input_send_joypad_button`
Send a gamepad button press event.

**Arguments:**
- `button_index`: Button index (use `godot_input_get_constants`)
- `pressed` (optional): Whether pressed
- `device` (optional): Controller device ID (default: 0)

#### `godot_input_send_joypad_motion`
Send a gamepad axis motion event.

**Arguments:**
- `axis`: Axis index (use `godot_input_get_constants`)
- `axis_value`: Axis value (-1.0 to 1.0 for sticks, 0.0 to 1.0 for triggers)
- `device` (optional): Controller device ID (default: 0)

#### `godot_input_get_constants`
Get constant values for key codes, mouse buttons, and joypad controls.

**Arguments:**
- `type` (optional): Type of constants: `all`, `keys`, `mouse`, `joypad` (default: `all`)

**Example:**
```json
{
  "name": "godot_input_get_constants",
  "arguments": {
    "type": "keys"
  }
}
```

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
