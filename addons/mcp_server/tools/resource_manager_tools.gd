extends RefCounted

var editor_interface: EditorInterface

func list_resource_files(args: Dictionary) -> Dictionary:
	return {"success": true, "resources": []}

func get_resource_info(args: Dictionary) -> Dictionary:
	return {"success": true}

func get_resource_properties(args: Dictionary) -> Dictionary:
	return {"success": true, "properties": []}

func set_resource_property(args: Dictionary) -> Dictionary:
	return {"success": true}

func create_resource(args: Dictionary) -> Dictionary:
	if not args.has("type"):
		return {"error": "Missing required parameter: type"}
	if not args.has("path"):
		return {"error": "Missing required parameter: path"}

	var resource_type: String = args.type
	var path: String = args.path

	if ResourceLoader.exists(path):
		return {"error": "Resource already exists at path: " + path}

	var resource: Resource

	match resource_type:
		"Resource":
			resource = Resource.new()
		_:
			resource = ClassDB.instantiate(resource_type)

	if resource == null:
		var script = _find_and_load_script(resource_type)
		if script:
			resource = script.new()

	if resource == null:
		return {"error": "Failed to instantiate resource type: " + resource_type}

	var save_result = ResourceSaver.save(resource, path)
	if save_result != OK:
		return {"error": "Failed to save resource: " + error_string(save_result)}

	return {
		"success": true,
		"path": path,
		"resource_type": resource_type,
		"message": "Resource created and saved"
	}

func delete_resource(args: Dictionary) -> Dictionary:
	if not args.has("path"):
		return {"error": "Missing required parameter: path"}

	var path: String = args.path

	if not ResourceLoader.exists(path):
		return {"error": "Resource not found: " + path}

	var dir = DirAccess.open(path.get_base_dir())
	if dir == null:
		return {"error": "Failed to access directory for resource"}

	var filename: String = path.get_file()
	var result = dir.remove(filename)

	if result != OK:
		return {"error": "Failed to delete resource: " + error_string(result)}

	return {"success": true, "path": path, "message": "Resource deleted"}

func duplicate_resource(args: Dictionary) -> Dictionary:
	if not args.has("source_path"):
		return {"error": "Missing required parameter: source_path"}
	if not args.has("destination_path"):
		return {"error": "Missing required parameter: destination_path"}

	var source_path: String = args.source_path
	var dest_path: String = args.destination_path

	if not ResourceLoader.exists(source_path):
		return {"error": "Source resource not found: " + source_path}

	if ResourceLoader.exists(dest_path):
		return {"error": "Destination resource already exists: " + dest_path}

	var resource = ResourceLoader.load(source_path)
	if resource == null:
		return {"error": "Failed to load source resource: " + source_path}

	var duplicated = resource.duplicate()
	if duplicated == null:
		return {"error": "Failed to duplicate resource"}

	var save_result = ResourceSaver.save(duplicated, dest_path)
	if save_result != OK:
		return {"error": "Failed to save duplicated resource: " + error_string(save_result)}

	return {"success": true, "source_path": source_path, "destination_path": dest_path, "message": "Resource duplicated"}

func _find_and_load_script(a_class_name: String) -> Variant:
	var global_classes = ProjectSettings.get_global_class_list()
	for class_info in global_classes:
		if class_info.get("class") == a_class_name:
			var script_path = class_info.get("path")
			if script_path:
				return ResourceLoader.load(script_path)
	return null
