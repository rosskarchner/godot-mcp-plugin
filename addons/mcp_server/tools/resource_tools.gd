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

func get_screenshot(args: Dictionary = {}) -> Dictionary:
	# Get parameters with defaults (optimized for <25k tokens)
	var max_width: int = args.get("max_width", 1280)
	var max_height: int = args.get("max_height", 720)
	var region_x: int = args.get("region_x", 0)
	var region_y: int = args.get("region_y", 0)
	var region_width: int = args.get("region_width", 0)
	var region_height: int = args.get("region_height", 0)
	
	# Get the main viewport
	var viewport := editor_interface.get_editor_viewport_3d(0)
	if not viewport:
		viewport = editor_interface.get_editor_viewport_2d()
	
	if not viewport:
		return {"error": "No viewport available"}
	
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

func run_scene(editor_plugin: EditorPlugin) -> Dictionary:
	# Play the current scene
	editor_interface.play_current_scene()
	
	return {
		"success": true,
		"message": "Scene started"
	}

func stop_scene(editor_plugin: EditorPlugin) -> Dictionary:
	# Stop the running scene
	editor_interface.stop_playing_scene()
	
	return {
		"success": true,
		"message": "Scene stopped"
	}

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
