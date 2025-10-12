extends RefCounted

## MCP Protocol Handler
##
## Implements the Model Context Protocol (MCP) with JSON-RPC 2.0.
## Handles core MCP methods and dispatches tool calls to specialized handlers.

const SceneTools = preload("res://addons/mcp_server/tools/scene_tools.gd")
const NodeTools = preload("res://addons/mcp_server/tools/node_tools.gd")
const ScriptTools = preload("res://addons/mcp_server/tools/script_tools.gd")
const ResourceTools = preload("res://addons/mcp_server/tools/resource_tools.gd")

var editor_interface: EditorInterface
var auth_token: String = ""
var allow_script_execution: bool = false
var max_tree_depth: int = 10

# Tool handlers
var scene_tools: SceneTools
var node_tools: NodeTools
var script_tools: ScriptTools
var resource_tools: ResourceTools

# Server capabilities
var server_info = {
	"name": "godot-mcp-server",
	"version": "1.0.0"
}

var capabilities = {
	"tools": {},
	"resources": {}
}


func _init() -> void:
	"""Initialize the MCP protocol handler."""
	scene_tools = SceneTools.new()
	node_tools = NodeTools.new()
	script_tools = ScriptTools.new()
	resource_tools = ResourceTools.new()


func set_editor_interface(ei: EditorInterface) -> void:
	"""Set the editor interface for all tool handlers."""
	editor_interface = ei
	scene_tools.editor_interface = ei
	node_tools.editor_interface = ei
	script_tools.editor_interface = ei
	resource_tools.editor_interface = ei


func handle_request(request: Dictionary) -> Dictionary:
	"""Handle an MCP JSON-RPC request and return a response."""
	var method = request.get("method", "")
	var params = request.get("params", {})
	var request_id = request.get("id")

	# Check authentication if token is set
	if auth_token != "" and not _check_auth(request):
		return _create_error_response(request_id, -32001, "Unauthorized")

	# Route to appropriate handler
	match method:
		"initialize":
			return _handle_initialize(request_id, params)
		"tools/list":
			return _handle_tools_list(request_id)
		"tools/call":
			return _handle_tool_call(request_id, params)
		"resources/list":
			return _handle_resources_list(request_id)
		"resources/read":
			return _handle_resource_read(request_id, params)
		_:
			return _create_error_response(request_id, -32601, "Method not found: " + method)


func _check_auth(request: Dictionary) -> bool:
	"""Check if request has valid authentication."""
	var params = request.get("params", {})
	var token = params.get("_auth_token", "")
	return token == auth_token


func _handle_initialize(request_id: Variant, params: Dictionary) -> Dictionary:
	"""Handle MCP initialize request."""
	print("[MCP Protocol] Initialize request from client: ", params.get("clientInfo", {}))

	var result = {
		"protocolVersion": "2024-11-05",
		"serverInfo": server_info,
		"capabilities": capabilities
	}

	return _create_success_response(request_id, result)


func _handle_tools_list(request_id: Variant) -> Dictionary:
	"""Return list of all available tools."""
	var tools = []

	# Add scene tools
	tools.append_array([
		_tool_schema("get_scene_tree", "Get the hierarchical structure of the current scene", {
			"type": "object",
			"properties": {
				"max_depth": {"type": "integer", "description": "Maximum depth to traverse (default: 10)"}
			}
		}),
		_tool_schema("get_current_scene", "Get information about the currently edited scene", {}),
		_tool_schema("save_scene", "Save the current scene", {}),
		_tool_schema("load_scene", "Load a different scene", {
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "Path to the scene file (e.g., 'res://scenes/main.tscn')"}
			},
			"required": ["path"]
		})
	])

	# Add node tools
	tools.append_array([
		_tool_schema("get_node_info", "Get detailed information about a specific node", {
			"type": "object",
			"properties": {
				"node_path": {"type": "string", "description": "NodePath to the target node (e.g., 'Player' or 'Level/Enemy')"}
			},
			"required": ["node_path"]
		}),
		_tool_schema("get_node_properties", "List all properties of a node with their current values", {
			"type": "object",
			"properties": {
				"node_path": {"type": "string", "description": "NodePath to the target node"}
			},
			"required": ["node_path"]
		}),
		_tool_schema("set_node_property", "Set a property value on a specific node", {
			"type": "object",
			"properties": {
				"node_path": {"type": "string", "description": "NodePath to the target node"},
				"property": {"type": "string", "description": "Property name (e.g., 'position', 'rotation', 'modulate')"},
				"value": {"description": "New value for the property"}
			},
			"required": ["node_path", "property", "value"]
		}),
		_tool_schema("create_node", "Create a new node in the scene", {
			"type": "object",
			"properties": {
				"type": {"type": "string", "description": "Node type (e.g., 'Node2D', 'Sprite2D', 'CharacterBody3D')"},
				"name": {"type": "string", "description": "Name for the new node"},
				"parent_path": {"type": "string", "description": "Path to parent node (optional, defaults to scene root)"}
			},
			"required": ["type", "name"]
		}),
		_tool_schema("delete_node", "Delete a node from the scene", {
			"type": "object",
			"properties": {
				"node_path": {"type": "string", "description": "NodePath to the node to delete"}
			},
			"required": ["node_path"]
		}),
		_tool_schema("rename_node", "Rename a node", {
			"type": "object",
			"properties": {
				"node_path": {"type": "string", "description": "NodePath to the node to rename"},
				"new_name": {"type": "string", "description": "New name for the node"}
			},
			"required": ["node_path", "new_name"]
		}),
		_tool_schema("move_node", "Move a node to a different parent", {
			"type": "object",
			"properties": {
				"node_path": {"type": "string", "description": "NodePath to the node to move"},
				"new_parent_path": {"type": "string", "description": "Path to the new parent node"}
			},
			"required": ["node_path", "new_parent_path"]
		})
	])

	# Add script tools
	var script_tool_list = [
		_tool_schema("get_node_script", "Get the script attached to a node", {
			"type": "object",
			"properties": {
				"node_path": {"type": "string", "description": "NodePath to the node"}
			},
			"required": ["node_path"]
		}),
		_tool_schema("set_node_script", "Attach or modify a script on a node", {
			"type": "object",
			"properties": {
				"node_path": {"type": "string", "description": "NodePath to the node"},
				"script_path": {"type": "string", "description": "Path to the script file"}
			},
			"required": ["node_path", "script_path"]
		}),
		_tool_schema("get_script_source", "Read the source code of a script file", {
			"type": "object",
			"properties": {
				"script_path": {"type": "string", "description": "Path to the script file"}
			},
			"required": ["script_path"]
		}),
		_tool_schema("list_script_methods", "List methods defined in a script", {
			"type": "object",
			"properties": {
				"script_path": {"type": "string", "description": "Path to the script file"}
			},
			"required": ["script_path"]
		})
	]

	# Add execute_gdscript only if enabled
	if allow_script_execution:
		script_tool_list.append(_tool_schema("execute_gdscript", "Execute arbitrary GDScript code (SECURITY RISK: Only enable if trusted)", {
			"type": "object",
			"properties": {
				"code": {"type": "string", "description": "GDScript code to execute"}
			},
			"required": ["code"]
		}))

	tools.append_array(script_tool_list)

	# Add resource tools
	tools.append_array([
		_tool_schema("list_resources", "List resources in the project", {
			"type": "object",
			"properties": {
				"type_filter": {"type": "string", "description": "Filter by resource type (e.g., 'tscn', 'gd', 'png')"},
				"path": {"type": "string", "description": "Directory path to search (default: 'res://')"}
			}
		}),
		_tool_schema("get_resource_path", "Get filesystem path for a resource", {
			"type": "object",
			"properties": {
				"resource_name": {"type": "string", "description": "Name of the resource"}
			},
			"required": ["resource_name"]
		})
	])

	return _create_success_response(request_id, {"tools": tools})


func _tool_schema(name: String, description: String, input_schema: Dictionary) -> Dictionary:
	"""Create a tool schema definition."""
	return {
		"name": name,
		"description": description,
		"inputSchema": input_schema
	}


func _handle_tool_call(request_id: Variant, params: Dictionary) -> Dictionary:
	"""Execute a tool and return the result."""
	var tool_name = params.get("name", "")
	var arguments = params.get("arguments", {})

	print("[MCP Protocol] Tool call: ", tool_name)

	# Update tool handlers with current settings
	scene_tools.max_depth = max_tree_depth
	script_tools.allow_execution = allow_script_execution

	var result

	# Route to appropriate tool handler
	if tool_name.begins_with("get_scene") or tool_name.begins_with("save_scene") or tool_name.begins_with("load_scene"):
		result = scene_tools.execute(tool_name, arguments)
	elif tool_name.contains("node") and not tool_name.contains("script"):
		result = node_tools.execute(tool_name, arguments)
	elif tool_name.contains("script") or tool_name == "execute_gdscript":
		result = script_tools.execute(tool_name, arguments)
	elif tool_name.contains("resource"):
		result = resource_tools.execute(tool_name, arguments)
	else:
		return _create_error_response(request_id, -32602, "Unknown tool: " + tool_name)

	# Check for errors
	if result.has("error"):
		return _create_error_response(request_id, -32000, result.error)

	return _create_success_response(request_id, result)


func _handle_resources_list(request_id: Variant) -> Dictionary:
	"""List available MCP resources (optional feature)."""
	var resources = [
		{
			"uri": "godot://scene/current",
			"name": "Current Scene",
			"mimeType": "application/json",
			"description": "The currently edited scene structure"
		},
		{
			"uri": "godot://editor/settings",
			"name": "Editor Settings",
			"mimeType": "application/json",
			"description": "Current editor configuration"
		}
	]

	return _create_success_response(request_id, {"resources": resources})


func _handle_resource_read(request_id: Variant, params: Dictionary) -> Dictionary:
	"""Read a specific MCP resource."""
	var uri = params.get("uri", "")

	match uri:
		"godot://scene/current":
			var scene_data = scene_tools.execute("get_scene_tree", {})
			return _create_success_response(request_id, {
				"contents": [{
					"uri": uri,
					"mimeType": "application/json",
					"text": JSON.stringify(scene_data, "\t")
				}]
			})
		"godot://editor/settings":
			var settings = _get_editor_settings()
			return _create_success_response(request_id, {
				"contents": [{
					"uri": uri,
					"mimeType": "application/json",
					"text": JSON.stringify(settings, "\t")
				}]
			})
		_:
			return _create_error_response(request_id, -32602, "Unknown resource URI: " + uri)


func _get_editor_settings() -> Dictionary:
	"""Get current editor settings."""
	return {
		"max_tree_depth": max_tree_depth,
		"allow_script_execution": allow_script_execution,
		"authenticated": auth_token != ""
	}


func _create_success_response(request_id: Variant, result: Variant) -> Dictionary:
	"""Create a successful JSON-RPC 2.0 response."""
	return {
		"jsonrpc": "2.0",
		"result": result,
		"id": request_id
	}


func _create_error_response(request_id: Variant, code: int, message: String) -> Dictionary:
	"""Create a JSON-RPC 2.0 error response."""
	return {
		"jsonrpc": "2.0",
		"error": {
			"code": code,
			"message": message
		},
		"id": request_id
	}
