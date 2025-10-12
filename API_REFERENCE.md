# API Reference

Complete reference for all MCP tools provided by the Godot MCP Server Plugin.

## Table of Contents

- [Scene Management Tools](#scene-management-tools)
- [Node Operation Tools](#node-operation-tools)
- [Script Operation Tools](#script-operation-tools)
- [Resource Tools](#resource-tools)
- [Editor Tools](#editor-tools)
- [Type Conversion Reference](#type-conversion-reference)
- [Error Codes](#error-codes)

---

## Scene Management Tools

### get_scene_tree

Get the hierarchical structure of the current scene.

**Parameters:**
```json
{
  "max_depth": 10  // Optional: Maximum depth to traverse (default: 10)
}
```

**Returns:**
```json
{
  "scene_path": "res://scenes/main.tscn",
  "root": {
    "name": "Main",
    "type": "Node2D",
    "path": "/root/Main",
    "position": [0, 0],
    "rotation": 0,
    "scale": [1, 1],
    "children": [
      {
        "name": "Player",
        "type": "Sprite2D",
        "path": "/root/Main/Player",
        "position": [100, 100],
        "children": []
      }
    ]
  }
}
```

**Example Usage:**
```bash
curl -X POST http://localhost:8765 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "get_scene_tree",
      "arguments": {"max_depth": 5}
    },
    "id": 1
  }'
```

---

### get_current_scene

Get information about the currently edited scene.

**Parameters:** None

**Returns:**
```json
{
  "path": "res://scenes/main.tscn",
  "name": "Main",
  "type": "Node2D",
  "modified": true
}
```

---

### save_scene

Save the current scene to disk.

**Parameters:** None

**Returns:**
```json
{
  "success": true,
  "path": "res://scenes/main.tscn"
}
```

**Errors:**
```json
{
  "error": "No scene is currently open"
}
```

---

### load_scene

Load a different scene for editing.

**Parameters:**
```json
{
  "path": "res://scenes/level2.tscn"  // Required: Resource path to scene
}
```

**Returns:**
```json
{
  "success": true,
  "path": "res://scenes/level2.tscn"
}
```

**Errors:**
```json
{
  "error": "Scene file not found: res://scenes/level2.tscn"
}
```

---

## Node Operation Tools

### get_node_info

Get detailed information about a specific node.

**Parameters:**
```json
{
  "node_path": "/root/Main/Player"  // Required: Path to the node
}
```

**Returns:**
```json
{
  "name": "Player",
  "type": "Sprite2D",
  "path": "/root/Main/Player",
  "child_count": 2,
  "children": ["CollisionShape2D", "AnimatedSprite2D"],
  "parent": "Main",
  "script": "res://scripts/player.gd"
}
```

---

### get_node_properties

List all properties of a node with their current values.

**Parameters:**
```json
{
  "node_path": "/root/Main/Player"  // Required: Path to the node
}
```

**Returns:**
```json
{
  "node_path": "/root/Main/Player",
  "properties": {
    "position": {"type": "Vector2", "x": 100, "y": 200},
    "rotation": 0.0,
    "scale": {"type": "Vector2", "x": 1, "y": 1},
    "visible": true,
    "modulate": {"type": "Color", "r": 1, "g": 1, "b": 1, "a": 1}
  }
}
```

---

### set_node_property

Set a property value on a specific node.

**Parameters:**
```json
{
  "node_path": "/root/Main/Player",  // Required: Path to the node
  "property": "position",             // Required: Property name
  "value": [150, 250]                 // Required: New value
}
```

**Supported Value Formats:**

**Vector2/Vector3:**
```json
"value": [x, y]          // Array format
"value": [x, y, z]       // For Vector3
```

**Color:**
```json
"value": {"type": "Color", "r": 1.0, "g": 0.5, "b": 0.0, "a": 1.0}
```

**Simple types:**
```json
"value": 42              // int
"value": 3.14            // float
"value": true            // bool
"value": "text"          // string
```

**Returns:**
```json
{
  "success": true,
  "node_path": "/root/Main/Player",
  "property": "position",
  "value": {"type": "Vector2", "x": 150, "y": 250}
}
```

---

### create_node

Create a new node in the scene.

**Parameters:**
```json
{
  "parent_path": "/root/Main",     // Required: Path to parent node
  "node_type": "Sprite2D",         // Required: Type of node (must exist in ClassDB)
  "node_name": "NewSprite"         // Required: Name for the new node
}
```

**Common Node Types:**
- 2D: `Node2D`, `Sprite2D`, `AnimatedSprite2D`, `CollisionShape2D`, `Area2D`, `CharacterBody2D`, `StaticBody2D`
- 3D: `Node3D`, `MeshInstance3D`, `Camera3D`, `Light3D`, `CollisionShape3D`, `Area3D`
- Control: `Control`, `Button`, `Label`, `Panel`, `Container`, `HBoxContainer`, `VBoxContainer`
- Other: `Timer`, `AudioStreamPlayer`, `AnimationPlayer`

**Returns:**
```json
{
  "success": true,
  "node_path": "/root/Main/NewSprite",
  "name": "NewSprite",
  "type": "Sprite2D"
}
```

---

### delete_node

Delete a node from the scene.

**Parameters:**
```json
{
  "node_path": "/root/Main/OldSprite"  // Required: Path to the node
}
```

**Returns:**
```json
{
  "success": true,
  "deleted_path": "/root/Main/OldSprite"
}
```

**Errors:**
```json
{
  "error": "Cannot delete the root node"
}
```

---

### rename_node

Rename a node.

**Parameters:**
```json
{
  "node_path": "/root/Main/Player",  // Required: Path to the node
  "new_name": "MainCharacter"        // Required: New name
}
```

**Returns:**
```json
{
  "success": true,
  "old_name": "Player",
  "new_name": "MainCharacter",
  "new_path": "/root/Main/MainCharacter"
}
```

---

## Script Operation Tools

### get_node_script

Get the script attached to a node.

**Parameters:**
```json
{
  "node_path": "/root/Main/Player"  // Required: Path to the node
}
```

**Returns (with script):**
```json
{
  "has_script": true,
  "script_path": "res://scripts/player.gd",
  "node_path": "/root/Main/Player"
}
```

**Returns (without script):**
```json
{
  "has_script": false,
  "node_path": "/root/Main/Player"
}
```

---

### set_node_script

Attach or modify a script on a node.

**Parameters:**
```json
{
  "node_path": "/root/Main/Player",      // Required: Path to the node
  "script_path": "res://scripts/player.gd"  // Required: Path to script (empty to remove)
}
```

**Returns:**
```json
{
  "success": true,
  "node_path": "/root/Main/Player",
  "script_path": "res://scripts/player.gd",
  "action": "attached"  // or "removed"
}
```

---

### get_script_source

Read the source code of a script file.

**Parameters:**
```json
{
  "script_path": "res://scripts/player.gd"  // Required: Path to script
}
```

**Returns:**
```json
{
  "script_path": "res://scripts/player.gd",
  "source": "extends CharacterBody2D\n\nfunc _ready():\n\tpass\n"
}
```

---

### execute_gdscript

Execute arbitrary GDScript code.

**⚠️ Security Warning:** This tool compiles GDScript but does not execute arbitrary code for security reasons. Attach scripts to nodes for full execution.

**Parameters:**
```json
{
  "code": "print('Hello World')"  // Required: GDScript code
}
```

**Returns:**
```json
{
  "success": true,
  "warning": "Script compiled successfully. Direct execution is limited for safety.",
  "message": "To run code, attach it to a node or use the Godot debugger."
}
```

---

## Resource Tools

### list_resources

List resources in the project.

**Parameters:**
```json
{
  "directory": "res://scenes",  // Optional: Directory to list (default: "res://")
  "filter": ".tscn"             // Optional: File extension filter (default: "")
}
```

**Returns:**
```json
{
  "directory": "res://scenes",
  "filter": ".tscn",
  "resources": [
    {
      "name": "main.tscn",
      "path": "res://scenes/main.tscn",
      "type": "Scene"
    },
    {
      "name": "level2.tscn",
      "path": "res://scenes/level2.tscn",
      "type": "Scene"
    }
  ]
}
```

**Resource Types:**
- `Scene` - .tscn files
- `Binary Scene` - .scn files
- `GDScript` - .gd files
- `Resource` - .tres files
- `Binary Resource` - .res files
- `Image` - .png, .jpg, .jpeg, .webp
- `Audio` - .wav, .ogg, .mp3
- `3D Model` - .glb, .gltf
- `Material/Shader` - .material, .shader
- `Unknown` - other files

---

### get_screenshot

Capture the current viewport as a base64-encoded PNG image.

**Parameters:** None

**Returns:**
```json
{
  "success": true,
  "format": "png",
  "width": 1920,
  "height": 1080,
  "data": "iVBORw0KGgoAAAANSUhEUgA..."  // Base64-encoded PNG
}
```

**Usage:**
The `data` field contains a base64-encoded PNG image. Decode it to display:

```javascript
// JavaScript example
const imgData = response.result.data;
const img = new Image();
img.src = 'data:image/png;base64,' + imgData;
document.body.appendChild(img);
```

---

### run_scene

Start playing the current scene.

**Parameters:** None

**Returns:**
```json
{
  "success": true,
  "message": "Scene started"
}
```

---

### stop_scene

Stop the running scene.

**Parameters:** None

**Returns:**
```json
{
  "success": true,
  "message": "Scene stopped"
}
```

---

## Editor Tools

### godot_editor_get_output

Read recent output from the Godot editor's log file. This captures all `print()` statements, errors, warnings, and other output from the editor and running game.

**Parameters:**
```json
{
  "max_lines": 100,      // Optional: Maximum number of recent log lines to return (default: 100)
  "filter_text": "error" // Optional: Filter log lines by text (case-insensitive, default: "")
}
```

**Returns:**
```json
{
  "success": true,
  "total_lines": 45,
  "max_lines": 100,
  "log_path": "/home/user/.local/share/godot/app_userdata/ProjectName/logs/godot.log",
  "lines": [
    "--- Debugging process started ---",
    "Godot Engine v4.2.stable.official",
    "Player position: (100, 200)",
    "ERROR: Null reference in update_health()",
    "..."
  ]
}
```

**Example Usage:**
```bash
# Get last 50 lines of output
curl -X POST http://localhost:8765 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "godot_editor_get_output",
      "arguments": {"max_lines": 50}
    },
    "id": 1
  }'

# Get lines containing "error"
curl -X POST http://localhost:8765 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "godot_editor_get_output",
      "arguments": {
        "max_lines": 100,
        "filter_text": "error"
      }
    },
    "id": 1
  }'
```

**Use Cases:**
- Debug scripts by checking print() output
- Monitor errors and warnings during development
- Check game output after running a scene
- Verify that specific log messages appear

---

## Type Conversion Reference

### Vector2

**From JSON:**
```json
[x, y]
// or
{"type": "Vector2", "x": 100, "y": 200}
```

**To JSON:**
```json
{"type": "Vector2", "x": 100, "y": 200}
```

### Vector3

**From JSON:**
```json
[x, y, z]
// or
{"type": "Vector3", "x": 100, "y": 200, "z": 300}
```

**To JSON:**
```json
{"type": "Vector3", "x": 100, "y": 200, "z": 300}
```

### Color

**From JSON:**
```json
{"type": "Color", "r": 1.0, "g": 0.5, "b": 0.0, "a": 1.0}
```

**To JSON:**
```json
{"type": "Color", "r": 1.0, "g": 0.5, "b": 0.0, "a": 1.0}
```

### NodePath

**From JSON:**
```json
"/root/Main/Player"
// or
{"type": "NodePath", "path": "/root/Main/Player"}
```

**To JSON:**
```json
{"type": "NodePath", "path": "/root/Main/Player"}
```

### Transform2D

**To JSON:**
```json
{
  "type": "Transform2D",
  "x": [1, 0],
  "y": [0, 1],
  "origin": [0, 0]
}
```

---

## Error Codes

### JSON-RPC 2.0 Standard Errors

| Code | Message | Meaning |
|------|---------|---------|
| -32700 | Parse error | Invalid JSON received |
| -32600 | Invalid Request | JSON not a valid Request object |
| -32601 | Method not found | Method does not exist |
| -32602 | Invalid params | Invalid method parameters |
| -32603 | Internal error | Internal JSON-RPC error |

### Tool-Specific Errors

Tool errors are returned in the result object:

```json
{
  "jsonrpc": "2.0",
  "result": {
    "error": "Node not found: /root/InvalidNode"
  },
  "id": 1
}
```

**Common Tool Errors:**
- `"No scene is currently open"` - No scene loaded in editor
- `"Node not found: <path>"` - Invalid node path
- `"Scene file not found: <path>"` - Scene file doesn't exist
- `"Missing required parameter: <param>"` - Required argument missing
- `"Property not found: <property>"` - Invalid property name
- `"Unknown node type: <type>"` - Invalid ClassDB class name
- `"Cannot delete the root node"` - Attempted to delete scene root
- `"Failed to open file: <path>"` - File access error

---

## MCP Protocol Methods

### initialize

Initialize the MCP connection.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "initialize",
  "params": {},
  "id": 1
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "protocolVersion": "2024-11-05",
    "capabilities": {
      "tools": {},
      "resources": {}
    },
    "serverInfo": {
      "name": "godot-mcp-server",
      "version": "1.0.0"
    }
  },
  "id": 1
}
```

### tools/list

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

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "tools": [
      {
        "name": "get_scene_tree",
        "description": "Get the hierarchical structure...",
        "inputSchema": { /* JSON Schema */ }
      },
      // ... more tools
    ]
  },
  "id": 2
}
```

### tools/call

Execute a tool.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "set_node_property",
    "arguments": {
      "node_path": "/root/Main/Player",
      "property": "position",
      "value": [200, 300]
    }
  },
  "id": 3
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "success": true,
    "node_path": "/root/Main/Player",
    "property": "position",
    "value": {"type": "Vector2", "x": 200, "y": 300}
  },
  "id": 3
}
```

### resources/list

List available resources.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "resources/list",
  "params": {},
  "id": 4
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "resources": [
      {
        "uri": "res://scenes/main.tscn",
        "name": "main.tscn",
        "mimeType": "application/x-godot-scene"
      }
    ]
  },
  "id": 4
}
```

### resources/read

Read a resource.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "resources/read",
  "params": {
    "uri": "res://scripts/player.gd"
  },
  "id": 5
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "contents": [{
      "uri": "res://scripts/player.gd",
      "mimeType": "text/x-gdscript",
      "text": "extends CharacterBody2D\n..."
    }]
  },
  "id": 5
}
```

---

## Complete Example Session

```bash
# 1. Initialize
curl -X POST http://localhost:8765 -H "Content-Type: application/json" -d '
{
  "jsonrpc": "2.0",
  "method": "initialize",
  "params": {},
  "id": 1
}'

# 2. List tools
curl -X POST http://localhost:8765 -H "Content-Type: application/json" -d '
{
  "jsonrpc": "2.0",
  "method": "tools/list",
  "params": {},
  "id": 2
}'

# 3. Get scene tree
curl -X POST http://localhost:8765 -H "Content-Type: application/json" -d '
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "get_scene_tree",
    "arguments": {"max_depth": 3}
  },
  "id": 3
}'

# 4. Create a new node
curl -X POST http://localhost:8765 -H "Content-Type: application/json" -d '
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "create_node",
    "arguments": {
      "parent_path": "/root/Main",
      "node_type": "Sprite2D",
      "node_name": "Enemy"
    }
  },
  "id": 4
}'

# 5. Set node property
curl -X POST http://localhost:8765 -H "Content-Type: application/json" -d '
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "set_node_property",
    "arguments": {
      "node_path": "/root/Main/Enemy",
      "property": "position",
      "value": [300, 400]
    }
  },
  "id": 5
}'

# 6. Save scene
curl -X POST http://localhost:8765 -H "Content-Type: application/json" -d '
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "save_scene",
    "arguments": {}
  },
  "id": 6
}'
```

---

## Notes

- All node paths should be absolute from the scene root
- The scene must be open in the editor for most operations
- Properties are case-sensitive
- Type conversions are automatic where possible
- Errors are returned in the result object, not as JSON-RPC errors
- Screenshots are base64-encoded PNG images
- Resource paths use Godot's `res://` protocol

For more information, see the main [README.md](README.md) and [QUICKSTART.md](QUICKSTART.md).
