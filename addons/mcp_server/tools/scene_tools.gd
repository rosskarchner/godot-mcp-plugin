extends RefCounted

## Scene Management Tools
##
## Provides MCP tools for scene inspection and manipulation.

var editor_interface: EditorInterface
var max_depth: int = 10


func execute(tool_name: String, arguments: Dictionary) -> Dictionary:
	"""Execute a scene tool and return the result."""
	match tool_name:
		"get_scene_tree":
			return get_scene_tree(arguments.get("max_depth", max_depth))
		"get_current_scene":
			return get_current_scene()
		"save_scene":
			return save_scene()
		"load_scene":
			return load_scene(arguments.get("path", ""))
		_:
			return {"error": "Unknown tool: " + tool_name}


func get_scene_tree(depth: int = 10) -> Dictionary:
	"""Get the hierarchical structure of the current scene."""
	if not editor_interface:
		return {"error": "Editor interface not available"}

	var edited_scene = editor_interface.get_edited_scene_root()
	if not edited_scene:
		return {"error": "No scene is currently open"}

	var tree = _build_node_tree(edited_scene, 0, depth)

	return {
		"scene_path": edited_scene.scene_file_path,
		"root": tree,
		"max_depth_reached": depth
	}


func get_current_scene() -> Dictionary:
	"""Get information about the currently edited scene."""
	if not editor_interface:
		return {"error": "Editor interface not available"}

	var edited_scene = editor_interface.get_edited_scene_root()
	if not edited_scene:
		return {"error": "No scene is currently open"}

	return {
		"name": edited_scene.name,
		"type": edited_scene.get_class(),
		"path": edited_scene.scene_file_path,
		"is_modified": editor_interface.is_scene_modified(),
		"node_count": _count_nodes(edited_scene)
	}


func save_scene() -> Dictionary:
	"""Save the current scene."""
	if not editor_interface:
		return {"error": "Editor interface not available"}

	var edited_scene = editor_interface.get_edited_scene_root()
	if not edited_scene:
		return {"error": "No scene is currently open"}

	var scene_path = edited_scene.scene_file_path
	if scene_path == "":
		return {"error": "Scene has not been saved yet (no file path)"}

	# Save the scene
	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(edited_scene)

	if result != OK:
		return {"error": "Failed to pack scene: " + error_string(result)}

	result = ResourceSaver.save(packed_scene, scene_path)

	if result != OK:
		return {"error": "Failed to save scene: " + error_string(result)}

	return {
		"success": true,
		"path": scene_path,
		"message": "Scene saved successfully"
	}


func load_scene(path: String) -> Dictionary:
	"""Load a different scene."""
	if not editor_interface:
		return {"error": "Editor interface not available"}

	if path == "":
		return {"error": "Scene path is required"}

	if not FileAccess.file_exists(path):
		return {"error": "Scene file not found: " + path}

	# Open the scene in the editor
	editor_interface.open_scene_from_path(path)

	return {
		"success": true,
		"path": path,
		"message": "Scene loaded successfully"
	}


func _build_node_tree(node: Node, current_depth: int, max_depth: int) -> Dictionary:
	"""Recursively build a tree representation of a node and its children."""
	var tree = {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
		"children": []
	}

	# Add basic properties for common node types
	if node is Node2D:
		tree["position"] = var_to_str(node.position)
		tree["rotation"] = node.rotation
		tree["scale"] = var_to_str(node.scale)
	elif node is Node3D:
		tree["position"] = var_to_str(node.position)
		tree["rotation"] = var_to_str(node.rotation)
		tree["scale"] = var_to_str(node.scale)

	# Add script info if present
	if node.get_script():
		tree["script"] = node.get_script().resource_path

	# Recursively add children if within depth limit
	if current_depth < max_depth:
		for child in node.get_children():
			tree.children.append(_build_node_tree(child, current_depth + 1, max_depth))
	elif node.get_child_count() > 0:
		tree["children_truncated"] = node.get_child_count()

	return tree


func _count_nodes(node: Node) -> int:
	"""Count total number of nodes in a tree."""
	var count = 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count
