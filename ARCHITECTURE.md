# Architecture Documentation

This document describes the internal architecture of the Godot MCP Server Plugin.

## Overview

The plugin implements a Model Context Protocol (MCP) server over HTTP transport, allowing AI agents to interact with the Godot editor programmatically.

```
┌─────────────────────────────────────────────────────────────┐
│                    AI Agent (Claude, etc.)                   │
└───────────────────────────┬─────────────────────────────────┘
                            │ HTTP/JSON-RPC 2.0
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Godot MCP Server Plugin                   │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              mcp_server.gd (EditorPlugin)               ││
│  │  - Plugin lifecycle management                          ││
│  │  - Editor settings configuration                        ││
│  │  - Server start/stop control                            ││
│  └─────────────────────┬───────────────────────────────────┘│
│                        │                                     │
│  ┌────────────────────▼────────────────────────────────────┐│
│  │              http_handler.gd                            ││
│  │  - TCPServer management                                 ││
│  │  - HTTP request parsing                                 ││
│  │  - HTTP response generation                             ││
│  │  - Connection pooling                                   ││
│  └─────────────────────┬───────────────────────────────────┘│
│                        │                                     │
│  ┌────────────────────▼────────────────────────────────────┐│
│  │              mcp_protocol.gd                            ││
│  │  - JSON-RPC 2.0 protocol handling                       ││
│  │  - MCP method routing (initialize, tools/*, resources/*)││
│  │  - Tool schema definitions                              ││
│  │  - Request validation & error handling                  ││
│  └─────────────────────┬───────────────────────────────────┘│
│                        │                                     │
│         ┌──────────────┴──────────────┐                     │
│         ▼              ▼              ▼              ▼      │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐│
│  │  scene_   │  │  node_    │  │  script_  │  │ resource_ ││
│  │  tools.gd │  │  tools.gd │  │  tools.gd │  │ tools.gd  ││
│  │           │  │           │  │           │  │           ││
│  │ - get_    │  │ - get_    │  │ - get_    │  │ - list_   ││
│  │   scene_  │  │   node_   │  │   node_   │  │   resources││
│  │   tree    │  │   info    │  │   script  │  │ - get_    ││
│  │ - save_   │  │ - create_ │  │ - set_    │  │   screenshot││
│  │   scene   │  │   node    │  │   node_   │  │ - run_    ││
│  │ - load_   │  │ - delete_ │  │   script  │  │   scene   ││
│  │   scene   │  │   node    │  │ - execute_│  │ - stop_   ││
│  │ - get_    │  │ - set_    │  │   gdscript│  │   scene   ││
│  │   current_│  │   node_   │  │ - get_    │  │           ││
│  │   scene   │  │   property│  │   script_ │  │           ││
│  │           │  │           │  │   source  │  │           ││
│  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘│
│        │              │              │              │       │
│        └──────────────┴──────────────┴──────────────┘       │
│                        │                                     │
│                        ▼                                     │
│         ┌──────────────────────────────────────┐            │
│         │     Godot Editor Interface           │            │
│         │  - get_edited_scene_root()           │            │
│         │  - get_editor_interface()            │            │
│         │  - save_scene()                      │            │
│         │  - open_scene_from_path()            │            │
│         │  - play_current_scene()              │            │
│         └──────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

## Component Descriptions

### mcp_server.gd (Main Plugin)

**Responsibility:** Plugin lifecycle and configuration management.

**Key Functions:**
- `_enter_tree()` - Initialize plugin, create handlers, start server
- `_exit_tree()` - Clean up resources, stop server
- `_process()` - Poll HTTP handler for incoming requests
- `_setup_editor_settings()` - Configure editor settings
- `start_server()` / `stop_server()` - Control server lifecycle

**Configuration:**
- Port number (default: 8765)
- Auto-start flag
- Authentication token
- Max tree depth
- Screenshot limits

### http_handler.gd (HTTP Server)

**Responsibility:** HTTP transport layer.

**Key Functions:**
- `start()` - Start TCPServer on specified port
- `stop()` - Close all connections and stop server
- `poll()` - Accept new connections and process existing ones
- `_handle_request()` - Parse HTTP, route to MCP protocol
- `_parse_http_request()` - Extract method, headers, body
- `_send_json_response()` - Generate HTTP responses

**Features:**
- Connection pooling (max 10 concurrent)
- HTTP/1.1 request parsing
- CORS header support
- OPTIONS request handling
- Error response generation

### mcp_protocol.gd (Protocol Handler)

**Responsibility:** MCP and JSON-RPC 2.0 protocol implementation.

**Key Functions:**
- `handle_request()` - Main entry point for all requests
- `_handle_initialize()` - Server initialization
- `_handle_tools_list()` - Return available tools with schemas
- `_handle_tools_call()` - Execute tool by name
- `_handle_resources_list()` - List project resources
- `_handle_resources_read()` - Read resource content

**MCP Methods:**
- `initialize` → Server info and capabilities
- `tools/list` → Array of tool schemas
- `tools/call` → Execute tool, return result
- `resources/list` → Project file listing
- `resources/read` → File content

**Tool Schema Format:**
```gdscript
{
  "name": "tool_name",
  "description": "What it does",
  "inputSchema": {
    "type": "object",
    "properties": {
      "param": {
        "type": "string",
        "description": "Parameter description"
      }
    },
    "required": ["param"]
  }
}
```

### scene_tools.gd (Scene Management)

**Responsibility:** Scene-level operations.

**Tools:**
- `get_scene_tree()` - Recursive scene tree traversal
- `get_current_scene()` - Current scene metadata
- `save_scene()` - Save to disk
- `load_scene()` - Open different scene

**Features:**
- Configurable max depth traversal
- Transform data extraction (2D/3D)
- Hierarchical structure representation

### node_tools.gd (Node Operations)

**Responsibility:** Individual node manipulation.

**Tools:**
- `get_node_info()` - Node metadata and children
- `get_node_properties()` - All editable properties
- `set_node_property()` - Modify single property
- `create_node()` - Instantiate new node
- `delete_node()` - Remove from scene
- `rename_node()` - Change node name

**Features:**
- Type-aware property serialization
- Automatic type conversion (Vector2, Color, etc.)
- NodePath resolution
- Owner management for new nodes

### script_tools.gd (Script Operations)

**Responsibility:** Script management and execution.

**Tools:**
- `get_node_script()` - Check for attached script
- `set_node_script()` - Attach/detach script
- `get_script_source()` - Read script file
- `execute_gdscript()` - Compile (limited execution)

**Safety:**
- Script execution is compile-only
- No arbitrary code execution
- File system access validation

### resource_tools.gd (Resources & Utilities)

**Responsibility:** Project resources and visual feedback.

**Tools:**
- `list_resources()` - Recursive directory scan
- `get_screenshot()` - Viewport capture to PNG/base64
- `run_scene()` - Start playback
- `stop_scene()` - Stop playback

**Features:**
- File type detection
- Recursive directory traversal
- Image encoding to base64
- Filter by extension

## Data Flow

### Typical Request Flow

1. **Client sends HTTP POST** with JSON-RPC request
   ```json
   {
     "jsonrpc": "2.0",
     "method": "tools/call",
     "params": {
       "name": "create_node",
       "arguments": {...}
     },
     "id": 1
   }
   ```

2. **http_handler** receives TCP connection
   - Parses HTTP headers and body
   - Extracts JSON payload

3. **mcp_protocol** validates JSON-RPC
   - Checks protocol version
   - Validates method exists
   - Routes to handler

4. **Tool module** executes operation
   - Validates arguments
   - Accesses Godot editor interface
   - Performs operation
   - Returns result or error

5. **Response flows back**
   - mcp_protocol wraps in JSON-RPC format
   - http_handler generates HTTP response
   - TCP connection sends data and closes

### Error Handling Flow

Errors can occur at multiple levels:

**HTTP Level:**
- Bad request (400) - Malformed HTTP
- Method not allowed (405) - Not POST
- Internal server error (500) - Unexpected crash

**JSON-RPC Level:**
- Parse error (-32700) - Invalid JSON
- Invalid request (-32600) - Missing required fields
- Method not found (-32601) - Unknown method
- Invalid params (-32602) - Wrong parameter format

**Tool Level:**
- Returned in result object
- Tool-specific error messages
- Validation failures

## Extension Points

### Adding a New Tool

1. **Define schema** in `mcp_protocol.gd::_handle_tools_list()`:
```gdscript
tools.append(_create_tool_schema(
    "my_tool",
    "Description",
    {
        "type": "object",
        "properties": {...},
        "required": [...]
    }
))
```

2. **Add routing** in `mcp_protocol.gd::_handle_tools_call()`:
```gdscript
match tool_name:
    "my_tool":
        result = my_module.my_tool(arguments)
```

3. **Implement tool** in appropriate module:
```gdscript
func my_tool(args: Dictionary) -> Dictionary:
    # Validate args
    # Do work
    # Return result
    return {"success": true}
```

### Adding a New Module

1. Create `tools/new_module.gd`
2. Preload in `mcp_protocol.gd`
3. Instantiate in `_init()`
4. Set `editor_interface` reference
5. Add tools following pattern above

### Custom MCP Methods

Add new methods beyond standard MCP:

```gdscript
match method:
    "custom/method":
        result = _handle_custom_method(params)
```

## Performance Considerations

### Connection Management
- Max 10 concurrent connections
- Connections closed after response
- No persistent connections (HTTP/1.1 without Keep-Alive)

### Scene Tree Traversal
- Configurable max depth (default: 10)
- Prevents excessive recursion
- Early termination possible

### Screenshot Capture
- Resolution limits configurable
- PNG compression
- Base64 encoding overhead
- Consider caching for repeated requests

### Resource Listing
- Recursive directory scan
- Can be slow for large projects
- Consider pagination for production

## Security Architecture

### Network Security
- Binds to 127.0.0.1 (localhost only)
- No external network exposure
- CORS headers allow web clients

### Authentication
- Optional token in editor settings
- Token validation (if implemented)
- All operations logged

### Code Execution
- GDScript execution is compile-only
- No eval() or arbitrary execution
- Scripts must be attached to nodes

### File System Access
- Limited to project directory (res://)
- No absolute path access
- Read-only for most operations

## Testing Strategy

### Unit Testing
- Test individual tool functions
- Mock editor interface
- Validate error handling

### Integration Testing
- Use test scripts (test_server.sh/py)
- Test complete request/response cycle
- Verify all tools work

### Manual Testing
- Open example_project in Godot
- Use curl or MCP client
- Verify editor changes
- Check console logs

## Configuration System

Settings stored in EditorSettings:
```
mcp_server/port = 8765
mcp_server/auto_start = true
mcp_server/auth_token = ""
mcp_server/max_tree_depth = 10
mcp_server/screenshot_max_width = 1920
```

Access via:
```gdscript
EditorInterface.get_editor_settings().get_setting("mcp_server/port")
```

## Logging

All operations logged to Godot Output console:
- Server start/stop
- Request processing
- Errors and warnings
- Tool execution results

Format:
```
MCP Server Plugin loaded
MCP Server started on port 8765
```

## Future Enhancements

Potential improvements:
- WebSocket transport option
- Persistent connections (Server-Sent Events)
- Tool result caching
- Batch operations
- Undo/redo integration
- Animation timeline access
- Asset import pipeline access
- Debugger integration
- Profiler data access

## Godot Version Compatibility

**Current Target:** Godot 4.x

**Key Dependencies:**
- `EditorPlugin` API
- `TCPServer` for networking
- `EditorInterface` for editor access
- `ClassDB` for node instantiation

**Godot 3.x Port Considerations:**
- Different typing syntax
- StreamPeerTCP differences
- EditorInterface API changes
- No typed arrays

## License

MIT License - See LICENSE file for details.
