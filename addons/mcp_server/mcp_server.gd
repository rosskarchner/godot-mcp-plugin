@tool
extends EditorPlugin

## MCP Server Plugin for Godot Editor
##
## This plugin implements an HTTP transport MCP (Model Context Protocol) server
## that allows AI agents to inspect and manipulate the Godot editor and running games.
##
## Features:
## - HTTP server with JSON-RPC 2.0 support
## - Full MCP protocol implementation
## - Scene, node, script, and resource manipulation tools
## - Configurable settings and security options

const HTTPHandler = preload("res://addons/mcp_server/http_handler.gd")
const MCPProtocol = preload("res://addons/mcp_server/mcp_protocol.gd")

var http_handler: HTTPHandler
var mcp_protocol: MCPProtocol
var server_enabled: bool = false

# Editor settings paths
const SETTING_PORT = "mcp_server/network/port"
const SETTING_ENABLED = "mcp_server/network/enabled_on_start"
const SETTING_AUTH_TOKEN = "mcp_server/security/auth_token"
const SETTING_MAX_DEPTH = "mcp_server/limits/max_tree_depth"
const SETTING_SCREENSHOT_MAX = "mcp_server/limits/screenshot_max_size"
const SETTING_ALLOW_EXECUTE = "mcp_server/security/allow_script_execution"


func _enter_tree() -> void:
	print("[MCP Server] Plugin loaded")
	_setup_editor_settings()

	# Initialize protocol handler
	mcp_protocol = MCPProtocol.new()
	mcp_protocol.editor_interface = get_editor_interface()

	# Initialize HTTP handler
	http_handler = HTTPHandler.new()
	http_handler.mcp_protocol = mcp_protocol
	add_child(http_handler)

	# Auto-start if enabled
	if EditorInterface.get_editor_settings().get_setting(SETTING_ENABLED):
		start_server()


func _exit_tree() -> void:
	print("[MCP Server] Plugin unloading")
	stop_server()

	if http_handler:
		http_handler.queue_free()
		http_handler = null

	if mcp_protocol:
		mcp_protocol = null


func _setup_editor_settings() -> void:
	"""Setup default editor settings for the MCP server."""
	var editor_settings = EditorInterface.get_editor_settings()

	# Network settings
	if not editor_settings.has_setting(SETTING_PORT):
		editor_settings.set_setting(SETTING_PORT, 8765)
		editor_settings.set_initial_value(SETTING_PORT, 8765, false)
		editor_settings.add_property_info({
			"name": SETTING_PORT,
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "1024,65535"
		})

	if not editor_settings.has_setting(SETTING_ENABLED):
		editor_settings.set_setting(SETTING_ENABLED, false)
		editor_settings.set_initial_value(SETTING_ENABLED, false, false)

	# Security settings
	if not editor_settings.has_setting(SETTING_AUTH_TOKEN):
		editor_settings.set_setting(SETTING_AUTH_TOKEN, "")
		editor_settings.set_initial_value(SETTING_AUTH_TOKEN, "", false)

	if not editor_settings.has_setting(SETTING_ALLOW_EXECUTE):
		editor_settings.set_setting(SETTING_ALLOW_EXECUTE, false)
		editor_settings.set_initial_value(SETTING_ALLOW_EXECUTE, false, false)

	# Limits
	if not editor_settings.has_setting(SETTING_MAX_DEPTH):
		editor_settings.set_setting(SETTING_MAX_DEPTH, 10)
		editor_settings.set_initial_value(SETTING_MAX_DEPTH, 10, false)

	if not editor_settings.has_setting(SETTING_SCREENSHOT_MAX):
		editor_settings.set_setting(SETTING_SCREENSHOT_MAX, 1920)
		editor_settings.set_initial_value(SETTING_SCREENSHOT_MAX, 1920, false)


func start_server() -> void:
	"""Start the MCP HTTP server."""
	if server_enabled:
		print("[MCP Server] Already running")
		return

	var port = EditorInterface.get_editor_settings().get_setting(SETTING_PORT)
	var auth_token = EditorInterface.get_editor_settings().get_setting(SETTING_AUTH_TOKEN)
	var allow_execute = EditorInterface.get_editor_settings().get_setting(SETTING_ALLOW_EXECUTE)
	var max_depth = EditorInterface.get_editor_settings().get_setting(SETTING_MAX_DEPTH)

	# Configure protocol handler
	mcp_protocol.auth_token = auth_token
	mcp_protocol.allow_script_execution = allow_execute
	mcp_protocol.max_tree_depth = max_depth

	# Start HTTP server
	if http_handler.start(port):
		server_enabled = true
		print("[MCP Server] Started on port %d" % port)
		if auth_token != "":
			print("[MCP Server] Authentication enabled")
		if not allow_execute:
			print("[MCP Server] Script execution disabled for security")
	else:
		push_error("[MCP Server] Failed to start server on port %d" % port)


func stop_server() -> void:
	"""Stop the MCP HTTP server."""
	if not server_enabled:
		return

	http_handler.stop()
	server_enabled = false
	print("[MCP Server] Stopped")


func get_plugin_name() -> String:
	return "MCP Server"
