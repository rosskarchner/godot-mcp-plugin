extends RefCounted

## MCP Protocol Handler
##
## Implements the Model Context Protocol (MCP) over JSON-RPC 2.0.
## Handles initialization, tool listing, tool execution, and resource management.

const SceneTools = preload("res://addons/mcp_server/tools/scene_tools.gd")
const NodeTools = preload("res://addons/mcp_server/tools/node_tools.gd")
const ScriptTools = preload("res://addons/mcp_server/tools/script_tools.gd")
const ResourceTools = preload("res://addons/mcp_server/tools/resource_tools.gd")

var editor_interface: EditorInterface
var editor_plugin: EditorPlugin
var initialized: bool = false

# Tool modules
var scene_tools: SceneTools
var node_tools: NodeTools
var script_tools: ScriptTools
var resource_tools: ResourceTools

func _init() -> void:
	scene_tools = SceneTools.new()
	node_tools = NodeTools.new()
	script_tools = ScriptTools.new()
	resource_tools = ResourceTools.new()

func handle_request(request: Variant) -> Dictionary:
	# Validate JSON-RPC 2.0 format
	if not request is Dictionary:
		return _create_error(-32600, "Invalid Request: Expected object", null)
	
	var req := request as Dictionary
	
	if not req.has("jsonrpc") or req.jsonrpc != "2.0":
		return _create_error(-32600, "Invalid Request: Missing or invalid jsonrpc field", null)
	
	if not req.has("method"):
		return _create_error(-32600, "Invalid Request: Missing method field", null)
	
	var id = req.get("id", null)
	var method: String = req.method
	var params = req.get("params", {})
	
	# Route to appropriate handler
	var result: Variant
	
	match method:
		"initialize":
			result = _handle_initialize(params)
			initialized = true
		"tools/list":
			result = _handle_tools_list(params)
		"tools/call":
			result = _handle_tools_call(params)
		"resources/list":
			result = _handle_resources_list(params)
		"resources/read":
			result = _handle_resources_read(params)
		_:
			return _create_error(-32601, "Method not found: " + method, id)
	
	# Check for error result
	if result is Dictionary and result.has("error"):
		return _create_error(result.error.code, result.error.message, id)
	
	return _create_success(result, id)

func _handle_initialize(_params: Variant) -> Dictionary:
	return {
		"protocolVersion": "2024-11-05",
		"capabilities": {
			"tools": {},
			"resources": {}
		},
		"serverInfo": {
			"name": "godot-mcp-server",
			"version": "1.0.0"
		}
	}

func _handle_tools_list(_params: Variant) -> Dictionary:
	var tools: Array[Dictionary] = []
	
	# Scene management tools
	tools.append(_create_tool_schema(
		"get_scene_tree",
		"Get the hierarchical structure of the current scene including node types, names, and paths",
		{
			"type": "object",
			"properties": {
				"max_depth": {
					"type": "integer",
					"description": "Maximum depth to traverse (default: 10)",
					"default": 10
				}
			}
		}
	))
	
	tools.append(_create_tool_schema(
		"get_current_scene",
		"Get information about the currently edited scene",
		{"type": "object", "properties": {}}
	))
	
	tools.append(_create_tool_schema(
		"save_scene",
		"Save the current scene",
		{"type": "object", "properties": {}}
	))
	
	tools.append(_create_tool_schema(
		"load_scene",
		"Load a different scene for editing",
		{
			"type": "object",
			"properties": {
				"path": {
					"type": "string",
					"description": "Resource path to the scene file (e.g., 'res://scenes/main.tscn')"
				}
			},
			"required": ["path"]
		}
	))
	
	# Node operations
	tools.append(_create_tool_schema(
		"get_node_info",
		"Get detailed information about a specific node",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Path to the node (e.g., '/root/Node2D/Player')"
				}
			},
			"required": ["node_path"]
		}
	))
	
	tools.append(_create_tool_schema(
		"get_node_properties",
		"List all properties of a node with their current values",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Path to the node"
				}
			},
			"required": ["node_path"]
		}
	))
	
	tools.append(_create_tool_schema(
		"set_node_property",
		"Set a property value on a specific node",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Path to the node"
				},
				"property": {
					"type": "string",
					"description": "Property name (e.g., 'position', 'rotation')"
				},
				"value": {
					"description": "New value for the property"
				}
			},
			"required": ["node_path", "property", "value"]
		}
	))
	
	tools.append(_create_tool_schema(
		"create_node",
		"Create a new node in the scene",
		{
			"type": "object",
			"properties": {
				"parent_path": {
					"type": "string",
					"description": "Path to the parent node"
				},
				"node_type": {
					"type": "string",
					"description": "Type of node to create (e.g., 'Node2D', 'Sprite2D')"
				},
				"node_name": {
					"type": "string",
					"description": "Name for the new node"
				}
			},
			"required": ["parent_path", "node_type", "node_name"]
		}
	))
	
	tools.append(_create_tool_schema(
		"delete_node",
		"Delete a node from the scene",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Path to the node to delete"
				}
			},
			"required": ["node_path"]
		}
	))
	
	tools.append(_create_tool_schema(
		"rename_node",
		"Rename a node",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Path to the node"
				},
				"new_name": {
					"type": "string",
					"description": "New name for the node"
				}
			},
			"required": ["node_path", "new_name"]
		}
	))
	
	# Script operations
	tools.append(_create_tool_schema(
		"get_node_script",
		"Get the script attached to a node",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Path to the node"
				}
			},
			"required": ["node_path"]
		}
	))
	
	tools.append(_create_tool_schema(
		"set_node_script",
		"Attach or modify a script on a node",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Path to the node"
				},
				"script_path": {
					"type": "string",
					"description": "Path to the script file (e.g., 'res://scripts/player.gd')"
				}
			},
			"required": ["node_path", "script_path"]
		}
	))
	
	tools.append(_create_tool_schema(
		"get_script_source",
		"Read the source code of a script file",
		{
			"type": "object",
			"properties": {
				"script_path": {
					"type": "string",
					"description": "Path to the script file"
				}
			},
			"required": ["script_path"]
		}
	))
	
	tools.append(_create_tool_schema(
		"execute_gdscript",
		"Execute arbitrary GDScript code (USE WITH CAUTION)",
		{
			"type": "object",
			"properties": {
				"code": {
					"type": "string",
					"description": "GDScript code to execute"
				}
			},
			"required": ["code"]
		}
	))
	
	# Resource operations
	tools.append(_create_tool_schema(
		"list_resources",
		"List resources in the project",
		{
			"type": "object",
			"properties": {
				"directory": {
					"type": "string",
					"description": "Directory to list (e.g., 'res://scenes')",
					"default": "res://"
				},
				"filter": {
					"type": "string",
					"description": "File extension filter (e.g., '.tscn', '.gd')",
					"default": ""
				}
			}
		}
	))
	
	tools.append(_create_tool_schema(
		"get_screenshot",
		"Capture the current viewport as a base64-encoded PNG image",
		{"type": "object", "properties": {}}
	))
	
	tools.append(_create_tool_schema(
		"run_scene",
		"Start playing the current scene",
		{"type": "object", "properties": {}}
	))
	
	tools.append(_create_tool_schema(
		"stop_scene",
		"Stop the running scene",
		{"type": "object", "properties": {}}
	))
	
	return {"tools": tools}

func _handle_tools_call(params: Variant) -> Variant:
	if not params is Dictionary:
		return _create_error_result(-32602, "Invalid params: Expected object")
	
	var p := params as Dictionary
	
	if not p.has("name"):
		return _create_error_result(-32602, "Missing required parameter: name")
	
	var tool_name: String = p.name
	var arguments: Dictionary = p.get("arguments", {})
	
	# Set editor references for tool modules
	scene_tools.editor_interface = editor_interface
	node_tools.editor_interface = editor_interface
	script_tools.editor_interface = editor_interface
	resource_tools.editor_interface = editor_interface
	
	# Route to appropriate tool
	var result: Variant
	
	match tool_name:
		# Scene tools
		"get_scene_tree":
			result = scene_tools.get_scene_tree(arguments)
		"get_current_scene":
			result = scene_tools.get_current_scene()
		"save_scene":
			result = scene_tools.save_scene()
		"load_scene":
			result = scene_tools.load_scene(arguments)
		
		# Node tools
		"get_node_info":
			result = node_tools.get_node_info(arguments)
		"get_node_properties":
			result = node_tools.get_node_properties(arguments)
		"set_node_property":
			result = node_tools.set_node_property(arguments)
		"create_node":
			result = node_tools.create_node(arguments)
		"delete_node":
			result = node_tools.delete_node(arguments)
		"rename_node":
			result = node_tools.rename_node(arguments)
		
		# Script tools
		"get_node_script":
			result = script_tools.get_node_script(arguments)
		"set_node_script":
			result = script_tools.set_node_script(arguments)
		"get_script_source":
			result = script_tools.get_script_source(arguments)
		"execute_gdscript":
			result = script_tools.execute_gdscript(arguments)
		
		# Resource tools
		"list_resources":
			result = resource_tools.list_resources(arguments)
		"get_screenshot":
			result = resource_tools.get_screenshot()
		"run_scene":
			result = resource_tools.run_scene(editor_plugin)
		"stop_scene":
			result = resource_tools.stop_scene(editor_plugin)
		
		_:
			return _create_error_result(-32601, "Unknown tool: " + tool_name)
	
	return result

func _handle_resources_list(_params: Variant) -> Dictionary:
	# Return available scene files as resources
	var resources: Array[Dictionary] = []
	
	var dir := DirAccess.open("res://")
	if dir:
		_scan_directory_for_resources(dir, "res://", resources)
	
	return {"resources": resources}

func _scan_directory_for_resources(dir: DirAccess, path: String, resources: Array[Dictionary]) -> void:
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		
		var full_path := path + file_name
		
		if dir.current_is_dir():
			var subdir := DirAccess.open(full_path)
			if subdir:
				_scan_directory_for_resources(subdir, full_path + "/", resources)
		else:
			# Add file as resource
			resources.append({
				"uri": full_path,
				"name": file_name,
				"mimeType": _get_mime_type(file_name)
			})
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _handle_resources_read(params: Variant) -> Variant:
	if not params is Dictionary:
		return _create_error_result(-32602, "Invalid params: Expected object")
	
	var p := params as Dictionary
	
	if not p.has("uri"):
		return _create_error_result(-32602, "Missing required parameter: uri")
	
	var uri: String = p.uri
	
	if not FileAccess.file_exists(uri):
		return _create_error_result(-32002, "File not found: " + uri)
	
	var file := FileAccess.open(uri, FileAccess.READ)
	if not file:
		return _create_error_result(-32003, "Failed to open file: " + uri)
	
	var content := file.get_as_text()
	file.close()
	
	return {
		"contents": [{
			"uri": uri,
			"mimeType": _get_mime_type(uri),
			"text": content
		}]
	}

func _get_mime_type(filename: String) -> String:
	var ext := filename.get_extension().to_lower()
	
	match ext:
		"tscn", "scn":
			return "application/x-godot-scene"
		"gd":
			return "text/x-gdscript"
		"tres", "res":
			return "application/x-godot-resource"
		"json":
			return "application/json"
		"txt", "md":
			return "text/plain"
		_:
			return "application/octet-stream"

func _create_tool_schema(name: String, description: String, input_schema: Dictionary) -> Dictionary:
	return {
		"name": name,
		"description": description,
		"inputSchema": input_schema
	}

func _create_success(result: Variant, id: Variant) -> Dictionary:
	return {
		"jsonrpc": "2.0",
		"result": result,
		"id": id
	}

func _create_error(code: int, message: String, id: Variant) -> Dictionary:
	return {
		"jsonrpc": "2.0",
		"error": {
			"code": code,
			"message": message
		},
		"id": id
	}

func _create_error_result(code: int, message: String) -> Dictionary:
	return {
		"error": {
			"code": code,
			"message": message
		}
	}
