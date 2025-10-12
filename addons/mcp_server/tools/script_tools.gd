extends RefCounted

## Script Operations Tools
##
## Provides MCP tools for script inspection and manipulation.

var editor_interface: EditorInterface
var allow_execution: bool = false


func execute(tool_name: String, arguments: Dictionary) -> Dictionary:
	"""Execute a script tool and return the result."""
	match tool_name:
		"get_node_script":
			return get_node_script(arguments.get("node_path", ""))
		"set_node_script":
			return set_node_script(
				arguments.get("node_path", ""),
				arguments.get("script_path", "")
			)
		"get_script_source":
			return get_script_source(arguments.get("script_path", ""))
		"list_script_methods":
			return list_script_methods(arguments.get("script_path", ""))
		"execute_gdscript":
			return execute_gdscript(arguments.get("code", ""))
		_:
			return {"error": "Unknown tool: " + tool_name}


func get_node_script(node_path: String) -> Dictionary:
	"""Get the script attached to a node."""
	var node = _get_node(node_path)
	if not node:
		return {"error": "Node not found: " + node_path}

	var script = node.get_script()
	if not script:
		return {
			"node_path": node_path,
			"has_script": false,
			"message": "Node has no script attached"
		}

	return {
		"node_path": node_path,
		"has_script": true,
		"script_path": script.resource_path,
		"class_name": script.get_global_name(),
		"base_type": script.get_instance_base_type()
	}


func set_node_script(node_path: String, script_path: String) -> Dictionary:
	"""Attach or modify a script on a node."""
	var node = _get_node(node_path)
	if not node:
		return {"error": "Node not found: " + node_path}

	if script_path == "":
		# Remove script
		node.set_script(null)
		if editor_interface:
			editor_interface.mark_scene_as_unsaved()
		return {
			"success": true,
			"message": "Script removed from node"
		}

	# Load the script
	if not FileAccess.file_exists(script_path):
		return {"error": "Script file not found: " + script_path}

	var script = load(script_path)
	if not script:
		return {"error": "Failed to load script: " + script_path}

	if not script is Script:
		return {"error": "File is not a valid script: " + script_path}

	# Attach the script
	node.set_script(script)

	if editor_interface:
		editor_interface.mark_scene_as_unsaved()

	return {
		"success": true,
		"node_path": node_path,
		"script_path": script_path,
		"message": "Script attached successfully"
	}


func get_script_source(script_path: String) -> Dictionary:
	"""Read the source code of a script file."""
	if not FileAccess.file_exists(script_path):
		return {"error": "Script file not found: " + script_path}

	var file = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		return {"error": "Failed to open script file: " + script_path}

	var source = file.get_as_text()
	file.close()

	return {
		"script_path": script_path,
		"source": source,
		"line_count": source.split("\n").size()
	}


func list_script_methods(script_path: String) -> Dictionary:
	"""List methods defined in a script."""
	if not FileAccess.file_exists(script_path):
		return {"error": "Script file not found: " + script_path}

	var script = load(script_path)
	if not script:
		return {"error": "Failed to load script: " + script_path}

	if not script is Script:
		return {"error": "File is not a valid script: " + script_path}

	var methods = []
	var method_list = script.get_script_method_list()

	for method in method_list:
		var method_info = {
			"name": method.name,
			"args": []
		}

		# Add argument info
		if method.has("args"):
			for arg in method.args:
				method_info.args.append({
					"name": arg.name,
					"type": _type_to_string(arg.type)
				})

		# Add return type if available
		if method.has("return"):
			method_info["return_type"] = _type_to_string(method.return.type)

		methods.append(method_info)

	return {
		"script_path": script_path,
		"class_name": script.get_global_name(),
		"base_type": script.get_instance_base_type(),
		"methods": methods
	}


func execute_gdscript(code: String) -> Dictionary:
	"""Execute arbitrary GDScript code."""
	if not allow_execution:
		return {"error": "Script execution is disabled for security. Enable in editor settings."}

	if code == "":
		return {"error": "No code provided"}

	# Create a new script to execute the code
	var script = GDScript.new()

	# Wrap the code in a function
	var wrapped_code = """
extends RefCounted

func _execute():
	%s
""" % code

	script.source_code = wrapped_code
	var reload_result = script.reload()

	if reload_result != OK:
		return {
			"error": "Failed to compile script",
			"code": code,
			"details": error_string(reload_result)
		}

	# Try to execute the code
	var instance = script.new()
	if not instance:
		return {"error": "Failed to create script instance"}

	var result = null
	var error_msg = ""

	# Try to call the function and capture any errors
	if instance.has_method("_execute"):
		result = instance._execute()
	else:
		error_msg = "Script compiled but _execute method not found"

	return {
		"success": error_msg == "",
		"result": var_to_str(result) if result != null else null,
		"error": error_msg if error_msg != "" else null,
		"code": code
	}


func _get_node(node_path: String) -> Node:
	"""Get a node from the current scene by path."""
	if not editor_interface:
		return null

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return null

	# If path is just a name, search from root
	if not node_path.begins_with("/"):
		return root.find_child(node_path, true, false)

	# Otherwise use the full path
	return root.get_node_or_null(NodePath(node_path))


func _type_to_string(type: int) -> String:
	"""Convert a Variant.Type to a string."""
	match type:
		TYPE_NIL: return "null"
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR2I: return "Vector2i"
		TYPE_RECT2: return "Rect2"
		TYPE_VECTOR3: return "Vector3"
		TYPE_VECTOR3I: return "Vector3i"
		TYPE_TRANSFORM2D: return "Transform2D"
		TYPE_VECTOR4: return "Vector4"
		TYPE_VECTOR4I: return "Vector4i"
		TYPE_PLANE: return "Plane"
		TYPE_QUATERNION: return "Quaternion"
		TYPE_AABB: return "AABB"
		TYPE_BASIS: return "Basis"
		TYPE_TRANSFORM3D: return "Transform3D"
		TYPE_PROJECTION: return "Projection"
		TYPE_COLOR: return "Color"
		TYPE_STRING_NAME: return "StringName"
		TYPE_NODE_PATH: return "NodePath"
		TYPE_RID: return "RID"
		TYPE_OBJECT: return "Object"
		TYPE_CALLABLE: return "Callable"
		TYPE_SIGNAL: return "Signal"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_ARRAY: return "Array"
		TYPE_PACKED_BYTE_ARRAY: return "PackedByteArray"
		TYPE_PACKED_INT32_ARRAY: return "PackedInt32Array"
		TYPE_PACKED_INT64_ARRAY: return "PackedInt64Array"
		TYPE_PACKED_FLOAT32_ARRAY: return "PackedFloat32Array"
		TYPE_PACKED_FLOAT64_ARRAY: return "PackedFloat64Array"
		TYPE_PACKED_STRING_ARRAY: return "PackedStringArray"
		TYPE_PACKED_VECTOR2_ARRAY: return "PackedVector2Array"
		TYPE_PACKED_VECTOR3_ARRAY: return "PackedVector3Array"
		TYPE_PACKED_COLOR_ARRAY: return "PackedColorArray"
		_: return "Variant"
