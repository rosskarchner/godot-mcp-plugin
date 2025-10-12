extends RefCounted

## Node Operations Tools
##
## Provides MCP tools for node inspection and manipulation.

var editor_interface: EditorInterface


func execute(tool_name: String, arguments: Dictionary) -> Dictionary:
	"""Execute a node tool and return the result."""
	match tool_name:
		"get_node_info":
			return get_node_info(arguments.get("node_path", ""))
		"get_node_properties":
			return get_node_properties(arguments.get("node_path", ""))
		"set_node_property":
			return set_node_property(
				arguments.get("node_path", ""),
				arguments.get("property", ""),
				arguments.get("value")
			)
		"create_node":
			return create_node(
				arguments.get("type", ""),
				arguments.get("name", ""),
				arguments.get("parent_path", "")
			)
		"delete_node":
			return delete_node(arguments.get("node_path", ""))
		"rename_node":
			return rename_node(
				arguments.get("node_path", ""),
				arguments.get("new_name", "")
			)
		"move_node":
			return move_node(
				arguments.get("node_path", ""),
				arguments.get("new_parent_path", "")
			)
		_:
			return {"error": "Unknown tool: " + tool_name}


func get_node_info(node_path: String) -> Dictionary:
	"""Get detailed information about a specific node."""
	var node = _get_node(node_path)
	if not node:
		return {"error": "Node not found: " + node_path}

	var info = {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
		"parent": node.get_parent().name if node.get_parent() else null,
		"children_count": node.get_child_count(),
		"children": []
	}

	# List immediate children
	for child in node.get_children():
		info.children.append({
			"name": child.name,
			"type": child.get_class()
		})

	# Add type-specific properties
	if node is Node2D:
		info["node2d"] = {
			"position": var_to_str(node.position),
			"rotation": node.rotation,
			"scale": var_to_str(node.scale),
			"visible": node.visible
		}
	elif node is Node3D:
		info["node3d"] = {
			"position": var_to_str(node.position),
			"rotation": var_to_str(node.rotation),
			"scale": var_to_str(node.scale),
			"visible": node.visible
		}

	# Add script info
	if node.get_script():
		info["script"] = {
			"path": node.get_script().resource_path,
			"class_name": node.get_script().get_global_name()
		}

	return info


func get_node_properties(node_path: String) -> Dictionary:
	"""List all properties of a node with their current values."""
	var node = _get_node(node_path)
	if not node:
		return {"error": "Node not found: " + node_path}

	var properties = {}
	var property_list = node.get_property_list()

	for prop in property_list:
		# Skip internal and method properties
		if prop.usage & PROPERTY_USAGE_EDITOR:
			var prop_name = prop.name
			var value = node.get(prop_name)

			# Convert complex types to strings for JSON compatibility
			if value is Vector2 or value is Vector3 or value is Color:
				properties[prop_name] = var_to_str(value)
			elif value is Object and not value is Node:
				# For resources, store the path
				if value is Resource:
					properties[prop_name] = value.resource_path if value.resource_path != "" else "<embedded>"
				else:
					properties[prop_name] = "<Object:" + value.get_class() + ">"
			elif value is Array or value is Dictionary:
				properties[prop_name] = var_to_str(value)
			else:
				properties[prop_name] = value

	return {
		"node_path": node_path,
		"node_type": node.get_class(),
		"properties": properties
	}


func set_node_property(node_path: String, property: String, value: Variant) -> Dictionary:
	"""Set a property value on a specific node."""
	var node = _get_node(node_path)
	if not node:
		return {"error": "Node not found: " + node_path}

	# Check if property exists
	if not property in node:
		return {"error": "Property '%s' not found on node" % property}

	# Try to convert value to the appropriate type
	var converted_value = _convert_value(value, node.get(property))

	# Set the property
	node.set(property, converted_value)

	# Mark scene as modified
	if editor_interface:
		editor_interface.mark_scene_as_unsaved()

	return {
		"success": true,
		"node_path": node_path,
		"property": property,
		"new_value": var_to_str(converted_value),
		"message": "Property set successfully"
	}


func create_node(type: String, name: String, parent_path: String = "") -> Dictionary:
	"""Create a new node in the scene."""
	if not editor_interface:
		return {"error": "Editor interface not available"}

	# Get parent node
	var parent: Node
	if parent_path == "":
		parent = editor_interface.get_edited_scene_root()
	else:
		parent = _get_node(parent_path)

	if not parent:
		return {"error": "Parent node not found: " + parent_path}

	# Check if ClassDB knows this type
	if not ClassDB.class_exists(type):
		return {"error": "Unknown node type: " + type}

	# Check if it's a Node-derived class
	if not ClassDB.is_parent_class(type, "Node"):
		return {"error": "Type '%s' is not a Node class" % type}

	# Create the node
	var new_node = ClassDB.instantiate(type) as Node
	if not new_node:
		return {"error": "Failed to instantiate node of type: " + type}

	new_node.name = name
	parent.add_child(new_node)
	new_node.owner = editor_interface.get_edited_scene_root()

	# Mark scene as modified
	editor_interface.mark_scene_as_unsaved()

	return {
		"success": true,
		"node_path": str(new_node.get_path()),
		"type": type,
		"name": name,
		"message": "Node created successfully"
	}


func delete_node(node_path: String) -> Dictionary:
	"""Delete a node from the scene."""
	var node = _get_node(node_path)
	if not node:
		return {"error": "Node not found: " + node_path}

	# Don't allow deleting the root node
	if node == editor_interface.get_edited_scene_root():
		return {"error": "Cannot delete the scene root node"}

	var node_name = node.name
	node.queue_free()

	# Mark scene as modified
	if editor_interface:
		editor_interface.mark_scene_as_unsaved()

	return {
		"success": true,
		"deleted_node": node_name,
		"message": "Node deleted successfully"
	}


func rename_node(node_path: String, new_name: String) -> Dictionary:
	"""Rename a node."""
	var node = _get_node(node_path)
	if not node:
		return {"error": "Node not found: " + node_path}

	var old_name = node.name
	node.name = new_name

	# Mark scene as modified
	if editor_interface:
		editor_interface.mark_scene_as_unsaved()

	return {
		"success": true,
		"old_name": old_name,
		"new_name": new_name,
		"new_path": str(node.get_path()),
		"message": "Node renamed successfully"
	}


func move_node(node_path: String, new_parent_path: String) -> Dictionary:
	"""Move a node to a different parent."""
	var node = _get_node(node_path)
	if not node:
		return {"error": "Node not found: " + node_path}

	var new_parent = _get_node(new_parent_path)
	if not new_parent:
		return {"error": "New parent not found: " + new_parent_path}

	# Don't allow moving the root node
	if node == editor_interface.get_edited_scene_root():
		return {"error": "Cannot move the scene root node"}

	# Don't allow moving a node to one of its descendants
	if new_parent.is_ancestor_of(node):
		return {"error": "Cannot move node to one of its descendants"}

	var old_parent = node.get_parent()
	node.reparent(new_parent)

	# Mark scene as modified
	if editor_interface:
		editor_interface.mark_scene_as_unsaved()

	return {
		"success": true,
		"node": node.name,
		"old_parent": old_parent.name if old_parent else null,
		"new_parent": new_parent.name,
		"new_path": str(node.get_path()),
		"message": "Node moved successfully"
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


func _convert_value(value: Variant, target_type: Variant) -> Variant:
	"""Convert a value to match the target type."""
	# If value is already the right type, return it
	if typeof(value) == typeof(target_type):
		return value

	# Handle string conversions
	if value is String:
		var str_value = value as String

		# Vector2
		if target_type is Vector2:
			return str_to_var(str_value)

		# Vector3
		if target_type is Vector3:
			return str_to_var(str_value)

		# Color
		if target_type is Color:
			if str_value.begins_with("#"):
				return Color(str_value)
			return str_to_var(str_value)

		# Numbers
		if target_type is float:
			return float(str_value)
		if target_type is int:
			return int(str_value)

		# Bool
		if target_type is bool:
			return str_value.to_lower() in ["true", "1", "yes"]

	# Handle array/dict conversions for Vector2/Vector3
	if value is Array:
		if target_type is Vector2 and value.size() >= 2:
			return Vector2(value[0], value[1])
		if target_type is Vector3 and value.size() >= 3:
			return Vector3(value[0], value[1], value[2])
		if target_type is Color and value.size() >= 3:
			var a = 1.0 if value.size() < 4 else value[3]
			return Color(value[0], value[1], value[2], a)

	return value
