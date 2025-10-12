extends RefCounted

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
		var status := conn.get_status()
		
		if status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
			to_remove.append(i)
			continue
		
		if status == StreamPeerTCP.STATUS_CONNECTED:
			var available := conn.get_available_bytes()
			if available > 0:
				_handle_request(conn)
	
	# Remove closed connections (reverse order to maintain indices)
	to_remove.reverse()
	for i in to_remove:
		connections.remove_at(i)

func _handle_request(conn: StreamPeerTCP) -> void:
	var request_data := conn.get_data(BUFFER_SIZE)
	
	if request_data[0] != OK:
		conn.disconnect_from_host()
		return
	
	var request_text := request_data[1].get_string_from_utf8()
	
	# Parse HTTP request
	var parsed := _parse_http_request(request_text)
	
	if parsed.is_empty():
		_send_error_response(conn, 400, "Bad Request")
		return
	
	# Handle OPTIONS request (CORS preflight)
	if parsed.method == "OPTIONS":
		_send_options_response(conn)
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
			var result := mcp_protocol.handle_request(request)
			response_body = JSON.stringify(result)
	
	# Send response
	_send_json_response(conn, response_body)

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
	response += "Access-Control-Allow-Methods: POST, OPTIONS\r\n"
	response += "Access-Control-Allow-Headers: Content-Type\r\n"
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
