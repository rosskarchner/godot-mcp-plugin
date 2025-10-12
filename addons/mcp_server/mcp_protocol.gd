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
		"godot_scene_get_tree",
		"Inspect the scene hierarchy by retrieving the complete node tree structure of the currently open scene. Use this to understand scene composition, find specific nodes by path, or analyze the scene structure before making modifications. Returns node names, types, paths, children, and transform data for spatial nodes.",
		{
			"type": "object",
			"properties": {
				"max_depth": {
					"type": "integer",
					"description": "Maximum depth to traverse in the node hierarchy. Use lower values (3-5) for quick overviews, higher values (10+) for complete scene analysis. Default: 10",
					"default": 10
				}
			}
		}
	))

	tools.append(_create_tool_schema(
		"godot_scene_get_info",
		"Get metadata about the currently edited scene file. Use this to check which scene is open, verify the scene path before saving, or confirm you're working in the correct scene. Returns scene file path, root node name, and type.",
		{"type": "object", "properties": {}}
	))

	tools.append(_create_tool_schema(
		"godot_scene_save",
		"Save the current scene to disk, persisting all changes made to nodes, properties, and hierarchy. Use this after making modifications to preserve your work. Always call this before switching scenes or running tests to ensure changes are saved.",
		{"type": "object", "properties": {}}
	))

	tools.append(_create_tool_schema(
		"godot_scene_open",
		"Open a different scene file in the editor for editing. Use this to switch between scenes, load a scene for inspection, or prepare a specific scene for modification. The current scene will be closed (save first if needed).",
		{
			"type": "object",
			"properties": {
				"path": {
					"type": "string",
					"description": "Godot resource path to the scene file. Must use 'res://' prefix and end with '.tscn' or '.scn' extension. Example: 'res://scenes/levels/level_01.tscn'"
				}
			},
			"required": ["path"]
		}
	))
	
	# Node operations
	tools.append(_create_tool_schema(
		"godot_node_get_info",
		"Inspect a specific node to retrieve detailed information including its name, type, path, parent, children, and attached script. Use this to understand a node's role in the scene, verify its type before modifying properties, or check what script is attached. Essential before making node-specific modifications.",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Scene tree path to the node. Can be absolute (starting from root) like 'Player/Camera2D' or use full path notation. Get paths from godot_scene_get_tree first if unsure."
				}
			},
			"required": ["node_path"]
		}
	))

	tools.append(_create_tool_schema(
		"godot_node_list_properties",
		"List all editable properties of a node with their current values and types. Use this to discover what properties are available on a node before modifying them, debug current property values, or understand node configuration. Returns editor-visible properties only.",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Scene tree path to the node whose properties you want to inspect. Example: 'Player' or 'UI/HealthBar'"
				}
			},
			"required": ["node_path"]
		}
	))

	tools.append(_create_tool_schema(
		"godot_node_set_property",
		"Modify a property value on a specific node. Use this to change node behavior, update transforms (position/rotation/scale), modify appearance properties, or configure node settings. The property must exist on the node - use godot_node_list_properties first to see available properties.",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Scene tree path to the target node. Example: 'Player/Sprite2D'"
				},
				"property": {
					"type": "string",
					"description": "Exact name of the property to modify. Common examples: 'position' (Vector2/Vector3), 'rotation' (float/Vector3), 'scale' (Vector2/Vector3), 'visible' (bool), 'modulate' (Color)"
				},
				"value": {
					"description": "New value for the property. Type must match property expectations. For Vector2/Vector3, use {\"type\": \"Vector2\", \"x\": 100, \"y\": 50} or array [100, 50]. For Color: {\"type\": \"Color\", \"r\": 1, \"g\": 0, \"b\": 0, \"a\": 1}"
				}
			},
			"required": ["node_path", "property", "value"]
		}
	))

	tools.append(_create_tool_schema(
		"godot_node_create",
		"Add a new node as a child of an existing node in the scene. Use this to build scene structure, add gameplay elements, create UI components, or extend existing node hierarchies. The new node will be properly added to the scene tree and made editable.",
		{
			"type": "object",
			"properties": {
				"parent_path": {
					"type": "string",
					"description": "Scene tree path to the parent node that will contain the new node. Use '.' or root node name to add to scene root. Example: 'Player' or 'UI/Panel'"
				},
				"node_type": {
					"type": "string",
					"description": "Godot class name of the node type to instantiate. Must be a valid Godot node class. Common types: 'Node2D', 'Sprite2D', 'CharacterBody2D', 'Area2D', 'Camera2D', 'Node3D', 'MeshInstance3D', 'CollisionShape2D', 'Label', 'Button', 'Panel'"
				},
				"node_name": {
					"type": "string",
					"description": "Unique name for the new node within its parent. Should be descriptive and follow PascalCase convention. Example: 'PlayerSprite', 'AttackArea', 'MainCamera'"
				}
			},
			"required": ["parent_path", "node_type", "node_name"]
		}
	))

	tools.append(_create_tool_schema(
		"godot_node_delete",
		"Remove a node and all its children from the scene. Use this to clean up unused nodes, remove temporary test nodes, or restructure the scene hierarchy. Cannot delete the scene root node. Be careful - this operation removes all child nodes as well.",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Scene tree path to the node to remove. The node and all its children will be deleted. Example: 'TemporaryNode' or 'Enemies/Enemy1'"
				}
			},
			"required": ["node_path"]
		}
	))

	tools.append(_create_tool_schema(
		"godot_node_rename",
		"Change the name of a node in the scene tree. Use this to improve scene organization, fix naming inconsistencies, or make node purposes clearer. Note that this changes the node's path, so any references to the old path will need updating.",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Current scene tree path to the node you want to rename. Example: 'Sprite2D' or 'Player/OldName'"
				},
				"new_name": {
					"type": "string",
					"description": "New name for the node. Should be descriptive and follow PascalCase convention. Must be unique among siblings. Example: 'PlayerSprite', 'MainCamera', 'HealthBar'"
				}
			},
			"required": ["node_path", "new_name"]
		}
	))
	
	# Script operations
	tools.append(_create_tool_schema(
		"godot_script_get_from_node",
		"Check what script file is attached to a specific node. Use this to verify which script controls a node's behavior, find the script path for reading or editing, or check if a node has any script attached. Returns the script's resource path if one exists.",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Scene tree path to the node to inspect. Example: 'Player' or 'Enemies/Enemy1'"
				}
			},
			"required": ["node_path"]
		}
	))

	tools.append(_create_tool_schema(
		"godot_script_attach_to_node",
		"Attach a GDScript file to a node, giving it custom behavior and logic. Use this to add functionality to nodes, replace an existing script, or remove a script (by passing empty string). The script file must already exist in the project.",
		{
			"type": "object",
			"properties": {
				"node_path": {
					"type": "string",
					"description": "Scene tree path to the target node. Example: 'Player' or 'UI/HealthBar'"
				},
				"script_path": {
					"type": "string",
					"description": "Godot resource path to the GDScript file to attach. Use 'res://' prefix and '.gd' extension. Pass empty string \"\" to remove the current script. Example: 'res://scripts/player.gd'"
				}
			},
			"required": ["node_path", "script_path"]
		}
	))

	tools.append(_create_tool_schema(
		"godot_script_read_source",
		"Read the complete source code of a GDScript file. Use this to inspect script logic, understand node behavior, find functions to call, or prepare for script modifications. Returns the full text content of the .gd file.",
		{
			"type": "object",
			"properties": {
				"script_path": {
					"type": "string",
					"description": "Godot resource path to the script file to read. Must be a .gd file. Example: 'res://scripts/player.gd' or 'res://addons/my_plugin/tool.gd'"
				}
			},
			"required": ["script_path"]
		}
	))

	tools.append(_create_tool_schema(
		"godot_script_validate_code",
		"Validate GDScript code syntax by attempting to compile it. Use this to check if code is syntactically correct before writing to files, test code snippets, or verify script compilation. Does NOT execute the code for security reasons - only validates syntax.",
		{
			"type": "object",
			"properties": {
				"code": {
					"type": "string",
					"description": "Complete GDScript source code to validate. Should include proper class structure with extends statement. Example: 'extends Node2D\\nfunc _ready():\\n\\tpass'"
				}
			},
			"required": ["code"]
		}
	))
	
	# Resource operations
	tools.append(_create_tool_schema(
		"godot_project_list_files",
		"Scan the project directory to discover available resource files. Use this to explore project structure, find specific asset types, locate scenes or scripts, or get an overview of project contents. Can filter by file extension and search specific directories.",
		{
			"type": "object",
			"properties": {
				"directory": {
					"type": "string",
					"description": "Starting directory to scan. Use 'res://' for project root, or specify subdirectories like 'res://scenes', 'res://scripts', 'res://assets'. Defaults to entire project. Default: 'res://'",
					"default": "res://"
				},
				"filter": {
					"type": "string",
					"description": "File extension to filter results (include the dot). Leave empty to list all files. Examples: '.tscn' (scenes), '.gd' (scripts), '.png' (images), '.tres' (resources). Default: '' (all files)",
					"default": ""
				}
			}
		}
	))

	tools.append(_create_tool_schema(
		"godot_editor_capture_viewport",
		"Capture a screenshot of the current editor viewport as a base64-encoded PNG image. Use this to see what the scene looks like visually, debug rendering issues, verify node positions and appearance, or document the scene state. Captures the 2D or 3D editor viewport that's currently active.",
		{"type": "object", "properties": {}}
	))

	tools.append(_create_tool_schema(
		"godot_game_play_scene",
		"Start running the currently open scene in play mode. Use this to test scene functionality, verify game behavior, check physics interactions, or see scripts in action. Equivalent to pressing F6 or the 'Play Scene' button in the editor.",
		{"type": "object", "properties": {}}
	))

	tools.append(_create_tool_schema(
		"godot_game_stop_scene",
		"Stop the currently running scene and return to edit mode. Use this after testing is complete, when you need to make changes, or to reset the game state. Returns the editor to normal editing mode.",
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
		# Scene tools (new names)
		"godot_scene_get_tree":
			result = scene_tools.get_scene_tree(arguments)
		"godot_scene_get_info":
			result = scene_tools.get_current_scene()
		"godot_scene_save":
			result = scene_tools.save_scene()
		"godot_scene_open":
			result = scene_tools.load_scene(arguments)

		# Node tools (new names)
		"godot_node_get_info":
			result = node_tools.get_node_info(arguments)
		"godot_node_list_properties":
			result = node_tools.get_node_properties(arguments)
		"godot_node_set_property":
			result = node_tools.set_node_property(arguments)
		"godot_node_create":
			result = node_tools.create_node(arguments)
		"godot_node_delete":
			result = node_tools.delete_node(arguments)
		"godot_node_rename":
			result = node_tools.rename_node(arguments)

		# Script tools (new names)
		"godot_script_get_from_node":
			result = script_tools.get_node_script(arguments)
		"godot_script_attach_to_node":
			result = script_tools.set_node_script(arguments)
		"godot_script_read_source":
			result = script_tools.get_script_source(arguments)
		"godot_script_validate_code":
			result = script_tools.execute_gdscript(arguments)

		# Resource tools (new names)
		"godot_project_list_files":
			result = resource_tools.list_resources(arguments)
		"godot_editor_capture_viewport":
			result = resource_tools.get_screenshot()
		"godot_game_play_scene":
			result = resource_tools.run_scene(editor_plugin)
		"godot_game_stop_scene":
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
