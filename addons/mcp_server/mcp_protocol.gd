extends RefCounted

## MCP Protocol Handler
##
## Implements the Model Context Protocol (MCP) over JSON-RPC 2.0.
## Handles initialization, tool listing, tool execution, and resource management.

const SceneTools = preload("res://addons/mcp_server/tools/scene_tools.gd")
const NodeTools = preload("res://addons/mcp_server/tools/node_tools.gd")
const ScriptTools = preload("res://addons/mcp_server/tools/script_tools.gd")
const ResourceTools = preload("res://addons/mcp_server/tools/resource_tools.gd")
const EditorTools = preload("res://addons/mcp_server/tools/editor_tools.gd")
const ProjectTools = preload("res://addons/mcp_server/tools/project_tools.gd")
const InputMapTools = preload("res://addons/mcp_server/tools/input_map_tools.gd")
const InputEventTools = preload("res://addons/mcp_server/tools/input_event_tools.gd")

var editor_interface: EditorInterface
var editor_plugin: EditorPlugin
var initialized: bool = false

# Tool modules
var scene_tools: SceneTools
var node_tools: NodeTools
var script_tools: ScriptTools
var resource_tools: ResourceTools
var editor_tools: EditorTools
var project_tools: ProjectTools
var input_map_tools: InputMapTools
var input_event_tools: InputEventTools

func _init() -> void:
	scene_tools = SceneTools.new()
	node_tools = NodeTools.new()
	script_tools = ScriptTools.new()
	resource_tools = ResourceTools.new()
	editor_tools = EditorTools.new()
	project_tools = ProjectTools.new()
	input_map_tools = InputMapTools.new()
	input_event_tools = InputEventTools.new()

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
		"Capture a screenshot of the EDITOR viewport (scene editing view) as a base64-encoded PNG image. Use this to see what the scene looks like in the editor, verify node positions during scene design, check visual layout while editing, or document scene structure. This captures the 2D or 3D editor viewport where you edit scenes. Default resolution is optimized to stay under 25,000 tokens.",
		{
			"type": "object",
			"properties": {
				"max_width": {
					"type": "integer",
					"description": "Maximum width in pixels. Image will be downscaled proportionally if larger. Default: 1280",
					"default": 1280
				},
				"max_height": {
					"type": "integer",
					"description": "Maximum height in pixels. Image will be downscaled proportionally if larger. Default: 720",
					"default": 720
				},
				"region_x": {
					"type": "integer",
					"description": "X coordinate of the top-left corner of the region to capture. Default: 0 (full viewport)",
					"default": 0
				},
				"region_y": {
					"type": "integer",
					"description": "Y coordinate of the top-left corner of the region to capture. Default: 0 (full viewport)",
					"default": 0
				},
				"region_width": {
					"type": "integer",
					"description": "Width of the region to capture in pixels. Default: 0 (full viewport width)",
					"default": 0
				},
				"region_height": {
					"type": "integer",
					"description": "Height of the region to capture in pixels. Default: 0 (full viewport height)",
					"default": 0
				}
			}
		}
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
	
	# Editor tools
	tools.append(_create_tool_schema(
		"godot_editor_get_output",
		"Read recent output from the Godot editor's log file. This captures all print() statements, errors, warnings, and other output from the editor and running game. Use this to debug scripts, check for errors, or monitor game output during testing.",
		{
			"type": "object",
			"properties": {
				"max_lines": {
					"type": "integer",
					"description": "Maximum number of recent log lines to return. Default: 100",
					"default": 100
				},
				"filter_text": {
					"type": "string",
					"description": "Optional text to filter log lines (case-insensitive). Only lines containing this text will be returned. Default: '' (no filter)",
					"default": ""
				}
			}
		}
	))
	
	# Project configuration tools
	tools.append(_create_tool_schema(
		"godot_project_get_setting",
		"Get the value of a specific project setting from project.godot. Use this to check project configuration, read application settings, verify display properties, or inspect any configured project parameter. Common settings include 'application/config/name', 'display/window/size/width', 'physics/2d/default_gravity'.",
		{
			"type": "object",
			"properties": {
				"setting_name": {
					"type": "string",
					"description": "Full path to the project setting. Use forward slashes to separate categories. Examples: 'application/config/name', 'display/window/size/width', 'rendering/quality/driver/driver_name'"
				}
			},
			"required": ["setting_name"]
		}
	))
	
	tools.append(_create_tool_schema(
		"godot_project_set_setting",
		"Set a project setting value in project.godot. Use this to modify project configuration, change application properties, update display settings, or configure any project parameter. Changes are saved to disk. Be careful as invalid values can break the project.",
		{
			"type": "object",
			"properties": {
				"setting_name": {
					"type": "string",
					"description": "Full path to the project setting. Examples: 'application/config/name', 'display/window/size/width'"
				},
				"value": {
					"description": "New value for the setting. Type must match the setting's expected type. For Vector2/Vector3, use {\"type\": \"Vector2\", \"x\": 100, \"y\": 50}. For arrays, use JSON arrays."
				}
			},
			"required": ["setting_name", "value"]
		}
	))
	
	tools.append(_create_tool_schema(
		"godot_project_list_settings",
		"List all project settings or filter by category prefix. Use this to explore available project settings, discover configuration options, or find the correct setting path before modifying. Returns setting names, current values, and types.",
		{
			"type": "object",
			"properties": {
				"prefix": {
					"type": "string",
					"description": "Optional category prefix to filter settings. Examples: 'application/', 'display/', 'input/', 'physics/'. Leave empty to list all settings. Default: ''",
					"default": ""
				}
			}
		}
	))
	
	# Input map tools
	tools.append(_create_tool_schema(
		"godot_input_list_actions",
		"List all input actions configured in the project with their key/button bindings. Use this to discover what input actions exist, check current key mappings, or verify input configuration before modifying. Returns action names, events (keys/buttons), and deadzone values.",
		{"type": "object", "properties": {}}
	))
	
	tools.append(_create_tool_schema(
		"godot_input_get_action",
		"Get detailed information about a specific input action including all its input events and deadzone. Use this to inspect an action's configuration, verify key bindings, or check deadzone settings before making changes.",
		{
			"type": "object",
			"properties": {
				"action_name": {
					"type": "string",
					"description": "Name of the input action to inspect. Examples: 'ui_accept', 'move_left', 'jump', 'fire'"
				}
			},
			"required": ["action_name"]
		}
	))
	
	tools.append(_create_tool_schema(
		"godot_input_add_action",
		"Create a new input action in the project. Use this to add custom gameplay actions like 'jump', 'fire', 'interact'. After creating, add key/button events with godot_input_add_event. Changes are saved to project.godot.",
		{
			"type": "object",
			"properties": {
				"action_name": {
					"type": "string",
					"description": "Name for the new input action. Should be descriptive and lowercase_with_underscores. Examples: 'move_left', 'jump', 'fire', 'interact'"
				},
				"deadzone": {
					"type": "number",
					"description": "Deadzone value for analog inputs (0.0 to 1.0). Only affects joypad axes and triggers. Default: 0.5",
					"default": 0.5
				}
			},
			"required": ["action_name"]
		}
	))
	
	tools.append(_create_tool_schema(
		"godot_input_remove_action",
		"Delete an input action from the project. Use this to remove unused or temporary actions. Cannot be undone easily. Changes are saved to project.godot.",
		{
			"type": "object",
			"properties": {
				"action_name": {
					"type": "string",
					"description": "Name of the input action to remove. Example: 'old_action', 'temporary_test'"
				}
			},
			"required": ["action_name"]
		}
	))
	
	tools.append(_create_tool_schema(
		"godot_input_add_event",
		"Add a key, mouse button, or joypad button/axis event to an existing input action. Use this to bind keys to actions, add alternative keys, or configure controller inputs. Changes are saved to project.godot.",
		{
			"type": "object",
			"properties": {
				"action_name": {
					"type": "string",
					"description": "Name of the input action to add the event to. Example: 'move_left', 'jump'"
				},
				"event": {
					"type": "object",
					"description": "Input event specification. For keys: {\"type\": \"key\", \"keycode\": 65, \"pressed\": true}. For mouse: {\"type\": \"mouse_button\", \"button_index\": 1, \"pressed\": true}. For joypad button: {\"type\": \"joypad_button\", \"button_index\": 0, \"pressed\": true}. For joypad axis: {\"type\": \"joypad_motion\", \"axis\": 0, \"axis_value\": 1.0}. Use godot_input_get_constants to get key/button codes."
				}
			},
			"required": ["action_name", "event"]
		}
	))
	
	tools.append(_create_tool_schema(
		"godot_input_remove_event",
		"Remove a specific input event (key, button, etc.) from an action. Use this to unbind a key, remove duplicate bindings, or change input configuration. Changes are saved to project.godot.",
		{
			"type": "object",
			"properties": {
				"action_name": {
					"type": "string",
					"description": "Name of the input action to remove the event from"
				},
				"event": {
					"type": "object",
					"description": "Input event specification matching the event to remove. Same format as godot_input_add_event."
				}
			},
			"required": ["action_name", "event"]
		}
	))
	
	# Input event tools
	tools.append(_create_tool_schema(
		"godot_input_send_action",
		"Send a simulated input action event to the running game. Use this to test gameplay by triggering actions like 'jump', 'fire', 'move_left' without actually pressing keys. The game must be running (use godot_game_play_scene first). Equivalent to pressing a mapped action key.",
		{
			"type": "object",
			"properties": {
				"action_name": {
					"type": "string",
					"description": "Name of the input action to trigger. Must be a configured action. Examples: 'ui_accept', 'jump', 'fire'"
				},
				"pressed": {
					"type": "boolean",
					"description": "Whether the action is pressed (true) or released (false). Default: true",
					"default": true
				},
				"strength": {
					"type": "number",
					"description": "Strength/pressure of the input (0.0 to 1.0). Mainly for analog inputs. Default: 1.0",
					"default": 1.0
				}
			},
			"required": ["action_name"]
		}
	))
	
	tools.append(_create_tool_schema(
		"godot_input_send_key",
		"Send a simulated keyboard key press/release event to the running game. Use this to test keyboard input, type text, or trigger key-specific functionality. More direct than using actions. Supports modifier keys (Ctrl, Shift, Alt).",
		{
			"type": "object",
			"properties": {
				"keycode": {
					"type": "integer",
					"description": "Key code for the key to press. Use godot_input_get_constants to get common key codes. Examples: KEY_A (65), KEY_SPACE (32), KEY_ENTER (10)"
				},
				"physical_keycode": {
					"type": "integer",
					"description": "Physical key code (keyboard layout independent). Use either keycode or physical_keycode."
				},
				"pressed": {
					"type": "boolean",
					"description": "Whether the key is pressed (true) or released (false). Default: true",
					"default": true
				},
				"echo": {
					"type": "boolean",
					"description": "Whether this is a key repeat event. Default: false",
					"default": false
				},
				"alt_pressed": {
					"type": "boolean",
					"description": "Whether Alt modifier is pressed. Default: false",
					"default": false
				},
				"shift_pressed": {
					"type": "boolean",
					"description": "Whether Shift modifier is pressed. Default: false",
					"default": false
				},
				"ctrl_pressed": {
					"type": "boolean",
					"description": "Whether Ctrl modifier is pressed. Default: false",
					"default": false
				},
				"meta_pressed": {
					"type": "boolean",
					"description": "Whether Meta/Windows/Command key is pressed. Default: false",
					"default": false
				}
			}
		}
	))
	
	tools.append(_create_tool_schema(
		"godot_input_send_mouse_button",
		"Send a simulated mouse button press/release event. Use this to test mouse input, simulate clicks, or trigger mouse-specific functionality. Can specify screen position and support modifier keys.",
		{
			"type": "object",
			"properties": {
				"button_index": {
					"type": "integer",
					"description": "Mouse button to press. 1=Left, 2=Right, 3=Middle, 4=Wheel Up, 5=Wheel Down. Use godot_input_get_constants for button codes."
				},
				"pressed": {
					"type": "boolean",
					"description": "Whether the button is pressed (true) or released (false). Default: true",
					"default": true
				},
				"position_x": {
					"type": "number",
					"description": "X position of the mouse cursor. Default: 0.0",
					"default": 0.0
				},
				"position_y": {
					"type": "number",
					"description": "Y position of the mouse cursor. Default: 0.0",
					"default": 0.0
				},
				"double_click": {
					"type": "boolean",
					"description": "Whether this is a double-click event. Default: false",
					"default": false
				},
				"alt_pressed": {"type": "boolean", "default": false},
				"shift_pressed": {"type": "boolean", "default": false},
				"ctrl_pressed": {"type": "boolean", "default": false},
				"meta_pressed": {"type": "boolean", "default": false}
			},
			"required": ["button_index"]
		}
	))
	
	tools.append(_create_tool_schema(
		"godot_input_send_mouse_motion",
		"Send a simulated mouse motion event. Use this to test mouse movement, drag operations, or hover effects. Allows specifying position, relative movement, and velocity.",
		{
			"type": "object",
			"properties": {
				"position_x": {"type": "number", "description": "X position", "default": 0.0},
				"position_y": {"type": "number", "description": "Y position", "default": 0.0},
				"relative_x": {"type": "number", "description": "Relative X movement", "default": 0.0},
				"relative_y": {"type": "number", "description": "Relative Y movement", "default": 0.0},
				"velocity_x": {"type": "number", "description": "X velocity", "default": 0.0},
				"velocity_y": {"type": "number", "description": "Y velocity", "default": 0.0},
				"alt_pressed": {"type": "boolean", "default": false},
				"shift_pressed": {"type": "boolean", "default": false},
				"ctrl_pressed": {"type": "boolean", "default": false},
				"meta_pressed": {"type": "boolean", "default": false}
			}
		}
	))
	
	tools.append(_create_tool_schema(
		"godot_input_send_joypad_button",
		"Send a simulated gamepad/joypad button press event. Use this to test controller input without a physical controller. Supports pressure-sensitive buttons.",
		{
			"type": "object",
			"properties": {
				"button_index": {
					"type": "integer",
					"description": "Joypad button index. Use godot_input_get_constants for button codes. Examples: JOY_BUTTON_A (0), JOY_BUTTON_B (1)"
				},
				"pressed": {"type": "boolean", "default": true},
				"pressure": {
					"type": "number",
					"description": "Button pressure (0.0 to 1.0). Default: 1.0",
					"default": 1.0
				},
				"device": {
					"type": "integer",
					"description": "Joypad device ID (0 for first controller). Default: 0",
					"default": 0
				}
			},
			"required": ["button_index"]
		}
	))
	
	tools.append(_create_tool_schema(
		"godot_input_send_joypad_motion",
		"Send a simulated gamepad/joypad axis motion event. Use this to test analog stick or trigger input. Each axis ranges from -1.0 to 1.0 (sticks) or 0.0 to 1.0 (triggers).",
		{
			"type": "object",
			"properties": {
				"axis": {
					"type": "integer",
					"description": "Joypad axis index. Use godot_input_get_constants. Examples: JOY_AXIS_LEFT_X (0), JOY_AXIS_LEFT_Y (1)"
				},
				"axis_value": {
					"type": "number",
					"description": "Axis value. -1.0 to 1.0 for sticks, 0.0 to 1.0 for triggers."
				},
				"device": {
					"type": "integer",
					"description": "Joypad device ID (0 for first controller). Default: 0",
					"default": 0
				}
			},
			"required": ["axis", "axis_value"]
		}
	))
	
	tools.append(_create_tool_schema(
		"godot_input_get_constants",
		"Get helpful constant values for key codes, mouse buttons, and joypad buttons/axes. Use this to find the correct numeric values when creating input events. Returns common keyboard keys, mouse buttons, and gamepad controls.",
		{
			"type": "object",
			"properties": {
				"type": {
					"type": "string",
					"description": "Type of constants to retrieve: 'all', 'keys', 'mouse', 'joypad'. Default: 'all'",
					"default": "all"
				}
			}
		}
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
	editor_tools.editor_interface = editor_interface
	editor_tools.editor_plugin = editor_plugin
	project_tools.editor_interface = editor_interface
	input_map_tools.editor_interface = editor_interface
	input_event_tools.editor_interface = editor_interface
	input_event_tools.editor_plugin = editor_plugin
	
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
			result = resource_tools.get_editor_screenshot(arguments)
		"godot_game_play_scene":
			result = resource_tools.run_scene(editor_plugin)
		"godot_game_stop_scene":
			result = resource_tools.stop_scene(editor_plugin)
		
		# Editor tools
		"godot_editor_get_output":
			result = editor_tools.read_editor_logs(arguments)
		
		# Project configuration tools
		"godot_project_get_setting":
			result = project_tools.get_project_setting(arguments)
		"godot_project_set_setting":
			result = project_tools.set_project_setting(arguments)
		"godot_project_list_settings":
			result = project_tools.list_project_settings(arguments)
		
		# Input map tools
		"godot_input_list_actions":
			result = input_map_tools.list_input_actions(arguments)
		"godot_input_get_action":
			result = input_map_tools.get_input_action(arguments)
		"godot_input_add_action":
			result = input_map_tools.add_input_action(arguments)
		"godot_input_remove_action":
			result = input_map_tools.remove_input_action(arguments)
		"godot_input_add_event":
			result = input_map_tools.add_input_event_to_action(arguments)
		"godot_input_remove_event":
			result = input_map_tools.remove_input_event_from_action(arguments)
		
		# Input event tools
		"godot_input_send_action":
			result = input_event_tools.send_input_action(arguments)
		"godot_input_send_key":
			result = input_event_tools.send_key_event(arguments)
		"godot_input_send_mouse_button":
			result = input_event_tools.send_mouse_button_event(arguments)
		"godot_input_send_mouse_motion":
			result = input_event_tools.send_mouse_motion_event(arguments)
		"godot_input_send_joypad_button":
			result = input_event_tools.send_joypad_button_event(arguments)
		"godot_input_send_joypad_motion":
			result = input_event_tools.send_joypad_motion_event(arguments)
		"godot_input_get_constants":
			result = input_event_tools.get_input_constants(arguments)
		
		_:
			return _create_error_result(-32601, "Unknown tool: " + tool_name)
	
	# Check for error in result
	if result is Dictionary and result.has("error"):
		# Tool returned an error - convert to proper error format
		var error_message: String = result.error if result.error is String else str(result.error)
		return _create_error_result(-32000, error_message)
	
	# Wrap successful result in MCP content format
	return {
		"content": [
			{
				"type": "text",
				"text": JSON.stringify(result, "\t")
			}
		]
	}

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
