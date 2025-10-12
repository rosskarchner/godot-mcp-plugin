@tool
extends EditorPlugin

## MCP Server EditorPlugin
## 
## This plugin implements an HTTP-based Model Context Protocol (MCP) server that allows
## AI agents to interact with the Godot editor and running games.

const HTTPHandler = preload("res://addons/mcp_server/http_handler.gd")
const MCPProtocol = preload("res://addons/mcp_server/mcp_protocol.gd")

var http_handler: HTTPHandler
var mcp_protocol: MCPProtocol
var server_enabled: bool = false

## Default configuration
const DEFAULT_PORT: int = 8765
const SETTINGS_PREFIX: String = "mcp_server/"

func _enter_tree() -> void:
	# Initialize settings
	_setup_editor_settings()

	# Create protocol handler
	mcp_protocol = MCPProtocol.new()
	mcp_protocol.editor_interface = get_editor_interface()
	mcp_protocol.editor_plugin = self

	# Create HTTP server and add to tree so it gets _process calls
	http_handler = HTTPHandler.new()
	http_handler.name = "MCPHTTPServer"
	http_handler.mcp_protocol = mcp_protocol
	add_child(http_handler)

	# Start server if enabled
	if _get_setting("auto_start", true):
		start_server()

func _exit_tree() -> void:
	stop_server()

	if http_handler:
		remove_child(http_handler)
		http_handler.queue_free()
		http_handler = null

	if mcp_protocol:
		mcp_protocol.queue_free()
		mcp_protocol = null

func start_server() -> bool:
	if server_enabled:
		push_warning("MCP Server already running")
		return false
	
	var port: int = _get_setting("port", DEFAULT_PORT)
	
	if http_handler.start(port):
		server_enabled = true
		print("MCP Server started on port ", port)
		return true
	else:
		push_error("Failed to start MCP Server on port ", port)
		return false

func stop_server() -> void:
	if not server_enabled:
		return
	
	http_handler.stop()
	server_enabled = false

## Setup editor settings with defaults
func _setup_editor_settings() -> void:
	var settings := EditorInterface.get_editor_settings()
	
	# Port setting
	if not settings.has_setting(SETTINGS_PREFIX + "port"):
		settings.set_setting(SETTINGS_PREFIX + "port", DEFAULT_PORT)
	settings.set_initial_value(SETTINGS_PREFIX + "port", DEFAULT_PORT, false)
	settings.add_property_info({
		"name": SETTINGS_PREFIX + "port",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "1024,65535,1"
	})
	
	# Auto-start setting
	if not settings.has_setting(SETTINGS_PREFIX + "auto_start"):
		settings.set_setting(SETTINGS_PREFIX + "auto_start", true)
	settings.set_initial_value(SETTINGS_PREFIX + "auto_start", true, false)
	settings.add_property_info({
		"name": SETTINGS_PREFIX + "auto_start",
		"type": TYPE_BOOL
	})
	
	# Authentication token (optional)
	if not settings.has_setting(SETTINGS_PREFIX + "auth_token"):
		settings.set_setting(SETTINGS_PREFIX + "auth_token", "")
	settings.set_initial_value(SETTINGS_PREFIX + "auth_token", "", false)
	settings.add_property_info({
		"name": SETTINGS_PREFIX + "auth_token",
		"type": TYPE_STRING
	})
	
	# Max scene tree depth
	if not settings.has_setting(SETTINGS_PREFIX + "max_tree_depth"):
		settings.set_setting(SETTINGS_PREFIX + "max_tree_depth", 10)
	settings.set_initial_value(SETTINGS_PREFIX + "max_tree_depth", 10, false)
	settings.add_property_info({
		"name": SETTINGS_PREFIX + "max_tree_depth",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "1,100,1"
	})

func _get_setting(name: String, default_value: Variant) -> Variant:
	var settings := EditorInterface.get_editor_settings()
	var key := SETTINGS_PREFIX + name
	if settings.has_setting(key):
		return settings.get_setting(key)
	return default_value
