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

func get_screenshot() -> Dictionary:
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
	
	# Convert to PNG and encode as base64
	var png_data := image.save_png_to_buffer()
	var base64 := Marshalls.raw_to_base64(png_data)
	
	return {
		"success": true,
		"format": "png",
		"width": image.get_width(),
		"height": image.get_height(),
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
