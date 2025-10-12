extends RefCounted

## Resource Operations Tools
##
## Provides MCP tools for resource management and inspection.

var editor_interface: EditorInterface


func execute(tool_name: String, arguments: Dictionary) -> Dictionary:
	"""Execute a resource tool and return the result."""
	match tool_name:
		"list_resources":
			return list_resources(
				arguments.get("type_filter", ""),
				arguments.get("path", "res://")
			)
		"get_resource_path":
			return get_resource_path(arguments.get("resource_name", ""))
		_:
			return {"error": "Unknown tool: " + tool_name}


func list_resources(type_filter: String = "", base_path: String = "res://") -> Dictionary:
	"""List resources in the project."""
	if not DirAccess.dir_exists_absolute(base_path):
		return {"error": "Directory not found: " + base_path}

	var resources = []
	_scan_directory(base_path, type_filter, resources)

	return {
		"base_path": base_path,
		"type_filter": type_filter if type_filter != "" else "all",
		"count": resources.size(),
		"resources": resources
	}


func get_resource_path(resource_name: String) -> Dictionary:
	"""Get filesystem path for a resource by name."""
	if resource_name == "":
		return {"error": "Resource name is required"}

	# Search for the resource in the project
	var found_resources = []
	_find_resource_by_name("res://", resource_name, found_resources)

	if found_resources.is_empty():
		return {
			"resource_name": resource_name,
			"found": false,
			"message": "Resource not found"
		}

	return {
		"resource_name": resource_name,
		"found": true,
		"paths": found_resources,
		"count": found_resources.size()
	}


func _scan_directory(path: String, type_filter: String, results: Array) -> void:
	"""Recursively scan a directory for resources."""
	var dir = DirAccess.open(path)
	if not dir:
		push_error("Failed to open directory: " + path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = path + "/" + file_name if path != "res://" else path + file_name

		if dir.current_is_dir():
			# Skip hidden directories and .godot
			if not file_name.begins_with("."):
				_scan_directory(full_path, type_filter, results)
		else:
			# Check if file matches the type filter
			if type_filter == "" or file_name.ends_with("." + type_filter):
				var resource_info = {
					"path": full_path,
					"name": file_name,
					"type": _get_file_type(file_name),
					"size": _get_file_size(full_path)
				}
				results.append(resource_info)

		file_name = dir.get_next()

	dir.list_dir_end()


func _find_resource_by_name(path: String, resource_name: String, results: Array) -> void:
	"""Recursively search for resources by name."""
	var dir = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = path + "/" + file_name if path != "res://" else path + file_name

		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_find_resource_by_name(full_path, resource_name, results)
		else:
			# Check if filename matches (with or without extension)
			var name_without_ext = file_name.get_basename()
			if file_name == resource_name or name_without_ext == resource_name:
				results.append(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()


func _get_file_type(filename: String) -> String:
	"""Determine the resource type from filename."""
	var extension = filename.get_extension().to_lower()

	match extension:
		"tscn": return "scene"
		"scn": return "binary_scene"
		"gd": return "script"
		"gdshader": return "shader"
		"tres": return "resource"
		"res": return "binary_resource"
		"png", "jpg", "jpeg", "bmp", "svg", "webp": return "texture"
		"wav", "ogg", "mp3": return "audio"
		"glb", "gltf", "obj", "fbx": return "3d_model"
		"ttf", "otf", "woff", "woff2": return "font"
		"json": return "json"
		"txt", "md": return "text"
		_: return extension


func _get_file_size(path: String) -> int:
	"""Get the size of a file in bytes."""
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return 0

	var size = file.get_length()
	file.close()
	return size
