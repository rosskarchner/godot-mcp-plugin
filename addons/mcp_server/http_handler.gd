extends Node

## HTTP Server Handler
##
## Implements a robust HTTP/1.1 server using TCPServer for handling
## MCP protocol requests via JSON-RPC 2.0.

var tcp_server: TCPServer
var connections: Array[StreamPeerTCP] = []
var mcp_protocol = null  # Reference to MCPProtocol instance

const MAX_CONNECTIONS = 10
const BUFFER_SIZE = 65536


func _ready() -> void:
	tcp_server = TCPServer.new()
	set_process(false)  # Only process when server is active


func start(port: int) -> bool:
	"""Start the HTTP server on the specified port."""
	var err = tcp_server.listen(port, "127.0.0.1")
	if err != OK:
		push_error("[HTTP Handler] Failed to start server: " + error_string(err))
		return false

	set_process(true)
	print("[HTTP Handler] Listening on 127.0.0.1:%d" % port)
	return true


func stop() -> void:
	"""Stop the HTTP server and close all connections."""
	set_process(false)

	# Close all active connections
	for connection in connections:
		if connection.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			connection.disconnect_from_host()
	connections.clear()

	# Stop listening
	if tcp_server.is_listening():
		tcp_server.stop()

	print("[HTTP Handler] Server stopped")


func _process(_delta: float) -> void:
	"""Process incoming connections and requests."""
	# Accept new connections
	if tcp_server.is_connection_available():
		var connection = tcp_server.take_connection()
		if connections.size() < MAX_CONNECTIONS:
			connections.append(connection)
			print("[HTTP Handler] New connection accepted")
		else:
			connection.disconnect_from_host()
			print("[HTTP Handler] Connection rejected: max connections reached")

	# Process existing connections
	var i = 0
	while i < connections.size():
		var connection = connections[i]
		var status = connection.get_status()

		if status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
			connections.remove_at(i)
			continue

		if status == StreamPeerTCP.STATUS_CONNECTED and connection.get_available_bytes() > 0:
			_handle_request(connection)

		i += 1


func _handle_request(connection: StreamPeerTCP) -> void:
	"""Parse and handle an HTTP request."""
	var available = connection.get_available_bytes()
	if available == 0:
		return

	# Read the request data
	var raw_data = connection.get_data(min(available, BUFFER_SIZE))
	if raw_data[0] != OK:
		push_error("[HTTP Handler] Failed to read request data")
		connection.disconnect_from_host()
		return

	var request_data = raw_data[1].get_string_from_utf8()

	# Parse HTTP request
	var request = _parse_http_request(request_data)
	if request == null:
		_send_error_response(connection, 400, "Bad Request")
		connection.disconnect_from_host()
		return

	# Handle the request based on method
	if request.method == "OPTIONS":
		_send_cors_preflight(connection)
	elif request.method == "POST":
		_handle_post_request(connection, request)
	elif request.method == "GET":
		_handle_get_request(connection, request)
	else:
		_send_error_response(connection, 405, "Method Not Allowed")

	# Keep connection alive for potential reuse
	await get_tree().create_timer(0.1).timeout
	if connection.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		connection.disconnect_from_host()


func _parse_http_request(request_text: String) -> Dictionary:
	"""Parse HTTP request into structured data."""
	var lines = request_text.split("\r\n")
	if lines.size() == 0:
		return {}

	# Parse request line
	var request_line = lines[0].split(" ")
	if request_line.size() < 3:
		return {}

	var request = {
		"method": request_line[0],
		"path": request_line[1],
		"version": request_line[2],
		"headers": {},
		"body": ""
	}

	# Parse headers
	var i = 1
	var body_start = -1
	while i < lines.size():
		if lines[i] == "":
			body_start = i + 1
			break

		var header_parts = lines[i].split(": ", false, 1)
		if header_parts.size() == 2:
			request.headers[header_parts[0].to_lower()] = header_parts[1]
		i += 1

	# Extract body if present
	if body_start > 0 and body_start < lines.size():
		request.body = "\r\n".join(lines.slice(body_start))

	return request


func _handle_post_request(connection: StreamPeerTCP, request: Dictionary) -> void:
	"""Handle POST requests (main MCP endpoint)."""
	if not request.body or request.body == "":
		_send_error_response(connection, 400, "Empty request body")
		return

	# Parse JSON-RPC request
	var json = JSON.new()
	var parse_result = json.parse(request.body)

	if parse_result != OK:
		_send_json_rpc_error(connection, null, -32700, "Parse error")
		return

	var rpc_request = json.data
	if typeof(rpc_request) != TYPE_DICTIONARY:
		_send_json_rpc_error(connection, null, -32600, "Invalid Request")
		return

	# Validate JSON-RPC 2.0 format
	if not rpc_request.has("jsonrpc") or rpc_request.jsonrpc != "2.0":
		_send_json_rpc_error(connection, null, -32600, "Invalid JSON-RPC version")
		return

	if not rpc_request.has("method"):
		_send_json_rpc_error(connection, rpc_request.get("id"), -32600, "Missing method")
		return

	# Process the request through MCP protocol
	var response = mcp_protocol.handle_request(rpc_request)
	_send_json_response(connection, response)


func _handle_get_request(connection: StreamPeerTCP, request: Dictionary) -> void:
	"""Handle GET requests (health check, info endpoint)."""
	if request.path == "/" or request.path == "/health":
		var response = {
			"status": "ok",
			"server": "Godot MCP Server",
			"version": "1.0.0"
		}
		_send_json_response(connection, response, 200)
	else:
		_send_error_response(connection, 404, "Not Found")


func _send_cors_preflight(connection: StreamPeerTCP) -> void:
	"""Send CORS preflight response."""
	var response = "HTTP/1.1 204 No Content\r\n"
	response += "Access-Control-Allow-Origin: *\r\n"
	response += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
	response += "Access-Control-Allow-Headers: Content-Type, Authorization\r\n"
	response += "Access-Control-Max-Age: 86400\r\n"
	response += "\r\n"

	connection.put_data(response.to_utf8_buffer())


func _send_json_response(connection: StreamPeerTCP, data: Variant, status_code: int = 200) -> void:
	"""Send a JSON response with proper headers."""
	var json_string = JSON.stringify(data, "\t")
	var body = json_string.to_utf8_buffer()

	var status_text = "OK" if status_code == 200 else "Error"

	var response = "HTTP/1.1 %d %s\r\n" % [status_code, status_text]
	response += "Content-Type: application/json\r\n"
	response += "Content-Length: %d\r\n" % body.size()
	response += "Access-Control-Allow-Origin: *\r\n"
	response += "Connection: close\r\n"
	response += "\r\n"

	connection.put_data(response.to_utf8_buffer())
	connection.put_data(body)


func _send_json_rpc_error(connection: StreamPeerTCP, request_id: Variant, code: int, message: String) -> void:
	"""Send a JSON-RPC 2.0 error response."""
	var response = {
		"jsonrpc": "2.0",
		"error": {
			"code": code,
			"message": message
		},
		"id": request_id
	}
	_send_json_response(connection, response, 200)  # JSON-RPC errors still use 200


func _send_error_response(connection: StreamPeerTCP, status_code: int, message: String) -> void:
	"""Send an HTTP error response."""
	var body = message.to_utf8_buffer()

	var response = "HTTP/1.1 %d %s\r\n" % [status_code, message]
	response += "Content-Type: text/plain\r\n"
	response += "Content-Length: %d\r\n" % body.size()
	response += "Access-Control-Allow-Origin: *\r\n"
	response += "Connection: close\r\n"
	response += "\r\n"

	connection.put_data(response.to_utf8_buffer())
	connection.put_data(body)
