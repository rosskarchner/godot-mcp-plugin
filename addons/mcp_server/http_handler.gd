extends Node

## HTTP Handler
##
## Handles HTTP server functionality including request parsing, response generation,
## and routing to the MCP protocol handler.

var tcp_server: TCPServer
var connections: Array[StreamPeerTCP] = []
var mcp_protocol: RefCounted  # MCPProtocol instance
var port: int = 0

const MAX_CONNECTIONS: int = 10
const BUFFER_SIZE: int = 65536

func start(listen_port: int) -> bool:
	tcp_server = TCPServer.new()
	var err := tcp_server.listen(listen_port, "127.0.0.1")
	
	if err != OK:
		push_error("Failed to start HTTP server: ", error_string(err))
		return false
	
	port = listen_port
	return true

func stop() -> void:
	# Close all connections
	for conn in connections:
		if conn.get_status() != StreamPeerTCP.STATUS_NONE:
			conn.disconnect_from_host()
	connections.clear()
	
	# Stop server
	if tcp_server:
		tcp_server.stop()
		tcp_server = null

func _process(_delta: float) -> void:
	poll()

func poll() -> void:
	if not tcp_server:
		return

	# Accept new connections
	if tcp_server.is_connection_available():
		var conn := tcp_server.take_connection()
		if connections.size() < MAX_CONNECTIONS:
			connections.append(conn)
		else:
			# Too many connections, close it
			conn.disconnect_from_host()

	# Process existing connections
	var to_remove: Array[int] = []
	for i in range(connections.size()):
		var conn := connections[i]

		# Poll the connection to update its state
		conn.poll()
		var status := conn.get_status()

		if status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
			to_remove.append(i)
			continue

		if status == StreamPeerTCP.STATUS_CONNECTED:
			var available := conn.get_available_bytes()
			if available > 0:
				_handle_request(conn)
				to_remove.append(i)  # Remove after handling

	# Remove closed connections (reverse order to maintain indices)
	to_remove.reverse()
	for i in to_remove:
		connections.remove_at(i)

func _handle_request(conn: StreamPeerTCP) -> void:
	# Read all available data
	var available := conn.get_available_bytes()
	var request_data := conn.get_partial_data(available)

	if request_data[0] != OK:
		push_error("Error reading request data: ", error_string(request_data[0]))
		conn.disconnect_from_host()
		return

	var request_text: String = request_data[1].get_string_from_utf8()

	# Parse HTTP request
	var parsed := _parse_http_request(request_text)

	if parsed.is_empty():
		_send_error_response(conn, 400, "Bad Request")
		return

	# Validate Origin header for security (prevent DNS rebinding attacks)
	# Only accept requests without Origin header (local tools) or from localhost
	if parsed.headers.has("origin"):
		var origin: String = parsed.headers["origin"]
		if not _is_safe_origin(origin):
			_send_error_response(conn, 403, "Forbidden: Invalid Origin")
			return

	# Handle OPTIONS request (CORS preflight)
	if parsed.method == "OPTIONS":
		_send_options_response(conn)
		return

	# Handle GET request (SSE stream)
	if parsed.method == "GET":
		# Check if client accepts SSE
		var accept: String = parsed.headers.get("accept", "") as String
		if "text/event-stream" in accept:
			# SSE not implemented yet, return 405
			_send_error_response(conn, 405, "Method Not Allowed: SSE not implemented")
		else:
			_send_error_response(conn, 405, "Method Not Allowed")
		return

	# Only accept POST requests for MCP
	if parsed.method != "POST":
		_send_error_response(conn, 405, "Method Not Allowed")
		return

	# Process MCP request
	var response_body: String

	if parsed.body.is_empty():
		response_body = _create_json_error(-32700, "Parse error: Empty request body")
	else:
		var json := JSON.new()
		var parse_result := json.parse(parsed.body)

		if parse_result != OK:
			response_body = _create_json_error(-32700, "Parse error: Invalid JSON")
		else:
			var request := json.data
			# Process through MCP protocol
			var result: Dictionary = mcp_protocol.handle_request(request)

			# Check if this was a notification (no response needed)
			if result.has("_notification") and result._notification:
				_send_accepted_response(conn)
				return

			response_body = JSON.stringify(result)
			# Fix integer IDs that get serialized as floats (e.g., "1.0" -> "1")
			response_body = _fix_json_integer_ids(response_body)

	# Send response
	_send_json_response(conn, response_body)

func _fix_json_integer_ids(json_string: String) -> String:
	# Fix JSON-RPC id field when it's an integer serialized as float
	# Replaces patterns like "id":1.0 with "id":1
	var regex := RegEx.new()
	regex.compile('"id":(\\d+)\\.0')
	return regex.sub(json_string, '"id":$1', true)

func _is_safe_origin(origin: String) -> bool:
	# Allow requests from localhost, 127.0.0.1, or null origin (local tools)
	if origin == "null":
		return true

	var safe_patterns := [
		"http://localhost",
		"https://localhost",
		"http://127.0.0.1",
		"https://127.0.0.1",
		"http://[::1]",
		"https://[::1]"
	]

	for pattern in safe_patterns:
		if origin.begins_with(pattern):
			return true

	return false

func _parse_http_request(request_text: String) -> Dictionary:
	var lines := request_text.split("\r\n")
	if lines.is_empty():
		return {}
	
	# Parse request line
	var request_line := lines[0].split(" ")
	if request_line.size() < 3:
		return {}
	
	var result := {
		"method": request_line[0],
		"path": request_line[1],
		"version": request_line[2],
		"headers": {},
		"body": ""
	}
	
	# Parse headers
	var i := 1
	var content_length := 0
	
	while i < lines.size() and not lines[i].is_empty():
		var header_line := lines[i]
		var colon_pos := header_line.find(":")
		
		if colon_pos > 0:
			var key := header_line.substr(0, colon_pos).strip_edges().to_lower()
			var value := header_line.substr(colon_pos + 1).strip_edges()
			result.headers[key] = value
			
			if key == "content-length":
				content_length = value.to_int()
		
		i += 1
	
	# Extract body
	i += 1  # Skip empty line after headers
	if i < lines.size():
		var body_start := request_text.find("\r\n\r\n")
		if body_start >= 0:
			result.body = request_text.substr(body_start + 4, content_length)
	
	return result

func _send_json_response(conn: StreamPeerTCP, json_body: String) -> void:
	var response := "HTTP/1.1 200 OK\r\n"
	response += "Content-Type: application/json\r\n"
	response += "Content-Length: " + str(json_body.length()) + "\r\n"
	response += _get_cors_headers()
	response += "\r\n"
	response += json_body

	conn.put_data(response.to_utf8_buffer())
	conn.disconnect_from_host()

func _send_accepted_response(conn: StreamPeerTCP) -> void:
	var response := "HTTP/1.1 202 Accepted\r\n"
	response += "Content-Length: 0\r\n"
	response += _get_cors_headers()
	response += "\r\n"

	conn.put_data(response.to_utf8_buffer())
	conn.disconnect_from_host()

func _send_error_response(conn: StreamPeerTCP, code: int, message: String) -> void:
	var response := "HTTP/1.1 " + str(code) + " " + message + "\r\n"
	response += "Content-Type: text/plain\r\n"
	response += "Content-Length: " + str(message.length()) + "\r\n"
	response += _get_cors_headers()
	response += "\r\n"
	response += message
	
	conn.put_data(response.to_utf8_buffer())
	conn.disconnect_from_host()

func _send_options_response(conn: StreamPeerTCP) -> void:
	var response := "HTTP/1.1 204 No Content\r\n"
	response += _get_cors_headers()
	response += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
	response += "Access-Control-Allow-Headers: Content-Type, Accept\r\n"
	response += "\r\n"

	conn.put_data(response.to_utf8_buffer())
	conn.disconnect_from_host()

func _get_cors_headers() -> String:
	return "Access-Control-Allow-Origin: *\r\n"

func _create_json_error(code: int, message: String) -> String:
	var error_obj := {
		"jsonrpc": "2.0",
		"error": {
			"code": code,
			"message": message
		},
		"id": null
	}
	return JSON.stringify(error_obj)
