# Changelog

All notable changes to the Godot MCP Server Plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-12

### Added
- Initial release of Godot MCP Server Plugin
- HTTP server implementation with JSON-RPC 2.0 protocol
- MCP protocol support for Model Context Protocol
- Scene management tools:
  - `get_scene_tree` - Get hierarchical scene structure
  - `get_current_scene` - Get current scene info
  - `save_scene` - Save the current scene
  - `load_scene` - Load a different scene
- Node operation tools:
  - `get_node_info` - Get detailed node information
  - `get_node_properties` - List all node properties
  - `set_node_property` - Modify node properties
  - `create_node` - Create new nodes
  - `delete_node` - Delete nodes
  - `rename_node` - Rename nodes
- Script operation tools:
  - `get_node_script` - Get attached script
  - `set_node_script` - Attach/detach scripts
  - `get_script_source` - Read script source code
  - `execute_gdscript` - Compile GDScript (limited execution for safety)
- Resource operation tools:
  - `list_resources` - List project resources
  - `get_screenshot` - Capture viewport screenshot
  - `run_scene` - Start scene playback
  - `stop_scene` - Stop scene playback
- Editor tools:
  - `godot_editor_get_output` - Read output from editor log file (captures print() statements, errors, warnings)
- Editor settings for configuration:
  - Configurable server port (default: 8765)
  - Auto-start on editor load option
  - Optional authentication token support
  - Max scene tree depth limit
  - Screenshot resolution limits
- CORS headers for web-based clients
- Comprehensive documentation:
  - Installation and usage guide
  - Tool reference documentation
  - Security best practices
  - Quick start guide
  - Example MCP client configuration
- Example Godot project for testing
- Type conversion support for GDScript types (Vector2, Vector3, Color, etc.)
- Error handling and logging
- Graceful server shutdown on plugin disable

### Security
- Server binds to localhost (127.0.0.1) only
- Script execution is limited for safety
- All operations logged to console
- Optional authentication token support

[1.0.0]: https://github.com/rosskarchner/godot-mcp-plugin/releases/tag/v1.0.0
