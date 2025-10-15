extends RefCounted

## Resource and Utility Tools
##
## Tools for resource management, screenshots, and scene playback.

var editor_interface: EditorInterface

func list_resources(args: Dictionary) -> Dictionary:
	var directory: String = args.get("directory", "res://")
	var filter: String = args.get("filter", "")
	
	var resources: Array[Dictionary] = []
	var dir := DirAccess.open(directory)
	
	if not dir:
		return {"error": "Failed to open directory: " + directory}
	
	_scan_directory(dir, directory, filter, resources)
	
	return {
		"directory": directory,
		"filter": filter,
		"resources": resources
	}

func get_editor_screenshot(args: Dictionary = {}) -> Dictionary:
	# Get parameters with defaults (optimized for <25k tokens)
	var max_width: int = args.get("max_width", 1280)
	var max_height: int = args.get("max_height", 720)
	var region_x: int = args.get("region_x", 0)
	var region_y: int = args.get("region_y", 0)
	var region_width: int = args.get("region_width", 0)
	var region_height: int = args.get("region_height", 0)

	# Get the editor viewport (not the running game)
	var viewport := editor_interface.get_editor_viewport_3d(0)
	if not viewport:
		viewport = editor_interface.get_editor_viewport_2d()

	if not viewport:
		return {"error": "No editor viewport available"}
	
	# Get the viewport texture
	var image := viewport.get_texture().get_image()
	
	if not image:
		return {"error": "Failed to capture viewport image"}
	
	var original_width := image.get_width()
	var original_height := image.get_height()
	
	# Apply region cropping if specified
	if region_width > 0 and region_height > 0:
		# Validate region bounds
		if region_x < 0 or region_y < 0 or \
		   region_x + region_width > original_width or \
		   region_y + region_height > original_height:
			return {
				"error": "Region out of bounds",
				"viewport_size": {"width": original_width, "height": original_height},
				"requested_region": {
					"x": region_x, 
					"y": region_y, 
					"width": region_width, 
					"height": region_height
				}
			}
		
		# Crop the image to the specified region
		var cropped := Image.create(region_width, region_height, false, image.get_format())
		cropped.blit_rect(image, Rect2i(region_x, region_y, region_width, region_height), Vector2i(0, 0))
		image = cropped
	
	# Apply resolution scaling if needed
	var current_width := image.get_width()
	var current_height := image.get_height()
	
	if current_width > max_width or current_height > max_height:
		# Calculate scale factor to fit within max dimensions while maintaining aspect ratio
		var scale_x := float(max_width) / float(current_width)
		var scale_y := float(max_height) / float(current_height)
		var scale := min(scale_x, scale_y)
		
		var new_width := int(current_width * scale)
		var new_height := int(current_height * scale)
		
		image.resize(new_width, new_height, Image.INTERPOLATE_LANCZOS)
	
	# Convert to PNG and encode as base64
	var png_data := image.save_png_to_buffer()
	var base64 := Marshalls.raw_to_base64(png_data)
	
	return {
		"success": true,
		"format": "png",
		"width": image.get_width(),
		"height": image.get_height(),
		"original_size": {"width": original_width, "height": original_height},
		"data": base64
	}

func run_scene(editor_plugin: EditorPlugin, args: Dictionary = {}) -> Dictionary:
	# Handle autoload injection if requested
	var enable_screenshot_api: bool = args.get("enable_screenshot_api", false)
	var autoload_enabled := false

	if enable_screenshot_api:
		# Add the game bridge autoload
		var autoload_path := "res://addons/mcp_server/runtime/mcp_game_bridge.gd"
		var autoload_name := "MCPGameBridge"

		# Check if autoload already exists
		if not ProjectSettings.has_setting("autoload/" + autoload_name):
			# Add autoload to project settings
			ProjectSettings.set_setting("autoload/" + autoload_name, autoload_path)
			var save_result := ProjectSettings.save()

			if save_result != OK:
				return {"error": "Failed to save autoload settings: " + error_string(save_result)}

			autoload_enabled = true

	# Play the current scene
	editor_interface.play_current_scene()

	var result := {
		"success": true,
		"message": "Scene started"
	}

	if enable_screenshot_api:
		result["screenshot_api"] = {
			"enabled": true,
			"port": 8766,
			"screenshot_endpoint": "http://127.0.0.1:8766/screenshot",
			"input_endpoint": "http://127.0.0.1:8766/input",
			"autoload_added": autoload_enabled,
			"note": "Game bridge API is available. Screenshot endpoint supports query params: max_width, max_height. Input endpoint accepts POST with JSON body containing event details."
		}

	return result

func stop_scene(editor_plugin: EditorPlugin) -> Dictionary:
	# Stop the running scene
	editor_interface.stop_playing_scene()

	return {
		"success": true,
		"message": "Scene stopped"
	}

func get_game_screenshot(args: Dictionary = {}) -> Dictionary:
	# Get parameters with defaults
	var max_width: int = args.get("max_width", 1280)
	var max_height: int = args.get("max_height", 720)
	var port: int = args.get("port", 8766)
	var save_to_disk: bool = args.get("save_to_disk", false)

	# Build URL with query parameters
	var url := "http://127.0.0.1:" + str(port) + "/screenshot"
	url += "?max_width=" + str(max_width)
	url += "&max_height=" + str(max_height)
	url += "&save_to_disk=" + ("true" if save_to_disk else "false")

	# Create HTTP request
	var http := HTTPClient.new()
	var err := http.connect_to_host("127.0.0.1", port)

	if err != OK:
		return {
			"error": "Failed to connect to game screenshot server. Is the game running with screenshot API enabled?",
			"details": error_string(err),
			"port": port
		}

	# Wait for connection
	var timeout := 30  # 3 seconds timeout (100ms per poll * 30)
	var poll_count := 0

	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		OS.delay_msec(100)
		poll_count += 1
		if poll_count > timeout:
			return {"error": "Connection timeout. Is the game running with screenshot API enabled?"}

	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		return {
			"error": "Failed to connect to game screenshot server",
			"status": http.get_status()
		}

	# Send request
	var request_path := "/screenshot?max_width=" + str(max_width) + "&max_height=" + str(max_height) + "&save_to_disk=" + ("true" if save_to_disk else "false")
	err = http.request(HTTPClient.METHOD_GET, request_path, [])

	if err != OK:
		return {"error": "Failed to send request: " + error_string(err)}

	# Wait for response
	poll_count = 0
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		OS.delay_msec(100)
		poll_count += 1
		if poll_count > timeout:
			return {"error": "Request timeout"}

	if not http.has_response():
		return {"error": "No response from server"}

	# Read response body
	var response_body := PackedByteArray()

	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk := http.read_response_body_chunk()
		if chunk.size() == 0:
			OS.delay_msec(100)
		else:
			response_body.append_array(chunk)

	# Parse JSON response
	var json := JSON.new()
	var parse_err := json.parse(response_body.get_string_from_utf8())

	if parse_err != OK:
		return {"error": "Failed to parse response: " + json.get_error_message()}

	var data = json.data

	if data is Dictionary:
		return data
	else:
		return {"error": "Invalid response format"}

func _scan_directory(dir: DirAccess, path: String, filter: String, resources: Array[Dictionary]) -> void:
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
				_scan_directory(subdir, full_path + "/", filter, resources)
		else:
			# Apply filter if specified
			if filter.is_empty() or file_name.ends_with(filter):
				resources.append({
					"name": file_name,
					"path": full_path,
					"type": _get_resource_type(file_name)
				})
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _get_resource_type(filename: String) -> String:
	var ext := filename.get_extension().to_lower()
	
	match ext:
		"tscn":
			return "Scene"
		"scn":
			return "Binary Scene"
		"gd":
			return "GDScript"
		"tres":
			return "Resource"
		"res":
			return "Binary Resource"
		"png", "jpg", "jpeg", "webp":
			return "Image"
		"wav", "ogg", "mp3":
			return "Audio"
		"glb", "gltf":
			return "3D Model"
		"material", "shader":
			return "Material/Shader"
		_:
			return "Unknown"
