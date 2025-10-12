extends RefCounted

## Input Event Tools
##
## Handles sending simulated input events to the running game or editor.

var editor_interface: EditorInterface
var editor_plugin: EditorPlugin

func send_input_action(args: Dictionary) -> Variant:
	"""Send an input action event (as if the player pressed a mapped action)."""
	if not args.has("action_name"):
		return {"error": "Missing required argument: action_name"}
	
	var action_name: String = args.action_name
	var pressed: bool = args.get("pressed", true)
	var strength: float = args.get("strength", 1.0)
	
	if not InputMap.has_action(action_name):
		return {"error": "Action not found: " + action_name}
	
	# Create an input action event
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = pressed
	event.strength = strength
	
	# Parse the input event to the running scene
	Input.parse_input_event(event)
	
	return {
		"success": true,
		"action_name": action_name,
		"pressed": pressed,
		"strength": strength,
		"message": "Input action sent"
	}

func send_key_event(args: Dictionary) -> Variant:
	"""Send a keyboard key event."""
	if not args.has("keycode") and not args.has("physical_keycode"):
		return {"error": "Missing required argument: keycode or physical_keycode"}
	
	var keycode: int = args.get("keycode", 0)
	var physical_keycode: int = args.get("physical_keycode", 0)
	var pressed: bool = args.get("pressed", true)
	var echo: bool = args.get("echo", false)
	
	# Modifiers
	var alt: bool = args.get("alt_pressed", false)
	var shift: bool = args.get("shift_pressed", false)
	var ctrl: bool = args.get("ctrl_pressed", false)
	var meta: bool = args.get("meta_pressed", false)
	
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = physical_keycode
	event.pressed = pressed
	event.echo = echo
	event.alt_pressed = alt
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	event.meta_pressed = meta
	
	Input.parse_input_event(event)
	
	return {
		"success": true,
		"keycode": keycode,
		"physical_keycode": physical_keycode,
		"pressed": pressed,
		"key_label": OS.get_keycode_string(keycode if keycode != 0 else physical_keycode),
		"message": "Key event sent"
	}

func send_mouse_button_event(args: Dictionary) -> Variant:
	"""Send a mouse button event."""
	if not args.has("button_index"):
		return {"error": "Missing required argument: button_index"}
	
	var button_index: int = args.button_index
	var pressed: bool = args.get("pressed", true)
	var position_x: float = args.get("position_x", 0.0)
	var position_y: float = args.get("position_y", 0.0)
	var double_click: bool = args.get("double_click", false)
	
	# Modifiers
	var alt: bool = args.get("alt_pressed", false)
	var shift: bool = args.get("shift_pressed", false)
	var ctrl: bool = args.get("ctrl_pressed", false)
	var meta: bool = args.get("meta_pressed", false)
	
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.position = Vector2(position_x, position_y)
	event.double_click = double_click
	event.alt_pressed = alt
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	event.meta_pressed = meta
	
	Input.parse_input_event(event)
	
	return {
		"success": true,
		"button_index": button_index,
		"pressed": pressed,
		"position": {"x": position_x, "y": position_y},
		"message": "Mouse button event sent"
	}

func send_mouse_motion_event(args: Dictionary) -> Variant:
	"""Send a mouse motion event."""
	var position_x: float = args.get("position_x", 0.0)
	var position_y: float = args.get("position_y", 0.0)
	var relative_x: float = args.get("relative_x", 0.0)
	var relative_y: float = args.get("relative_y", 0.0)
	var velocity_x: float = args.get("velocity_x", 0.0)
	var velocity_y: float = args.get("velocity_y", 0.0)
	
	# Modifiers
	var alt: bool = args.get("alt_pressed", false)
	var shift: bool = args.get("shift_pressed", false)
	var ctrl: bool = args.get("ctrl_pressed", false)
	var meta: bool = args.get("meta_pressed", false)
	
	var event := InputEventMouseMotion.new()
	event.position = Vector2(position_x, position_y)
	event.relative = Vector2(relative_x, relative_y)
	event.velocity = Vector2(velocity_x, velocity_y)
	event.alt_pressed = alt
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	event.meta_pressed = meta
	
	Input.parse_input_event(event)
	
	return {
		"success": true,
		"position": {"x": position_x, "y": position_y},
		"relative": {"x": relative_x, "y": relative_y},
		"message": "Mouse motion event sent"
	}

func send_joypad_button_event(args: Dictionary) -> Variant:
	"""Send a joypad button event."""
	if not args.has("button_index"):
		return {"error": "Missing required argument: button_index"}
	
	var button_index: int = args.button_index
	var pressed: bool = args.get("pressed", true)
	var pressure: float = args.get("pressure", 1.0)
	var device: int = args.get("device", 0)
	
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.pressure = pressure
	event.device = device
	
	Input.parse_input_event(event)
	
	return {
		"success": true,
		"button_index": button_index,
		"pressed": pressed,
		"device": device,
		"message": "Joypad button event sent"
	}

func send_joypad_motion_event(args: Dictionary) -> Variant:
	"""Send a joypad axis motion event."""
	if not args.has("axis"):
		return {"error": "Missing required argument: axis"}
	if not args.has("axis_value"):
		return {"error": "Missing required argument: axis_value"}
	
	var axis: int = args.axis
	var axis_value: float = args.axis_value
	var device: int = args.get("device", 0)
	
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	event.device = device
	
	Input.parse_input_event(event)
	
	return {
		"success": true,
		"axis": axis,
		"axis_value": axis_value,
		"device": device,
		"message": "Joypad motion event sent"
	}

func get_input_constants(args: Dictionary) -> Variant:
	"""Get helpful constants for key codes, mouse buttons, and joypad buttons."""
	var constant_type: String = args.get("type", "all")
	
	var result := {
		"success": true
	}
	
	if constant_type == "all" or constant_type == "keys":
		result["keys"] = {
			"KEY_ESCAPE": KEY_ESCAPE,
			"KEY_ENTER": KEY_ENTER,
			"KEY_SPACE": KEY_SPACE,
			"KEY_A": KEY_A,
			"KEY_B": KEY_B,
			"KEY_C": KEY_C,
			"KEY_D": KEY_D,
			"KEY_E": KEY_E,
			"KEY_F": KEY_F,
			"KEY_W": KEY_W,
			"KEY_S": KEY_S,
			"KEY_LEFT": KEY_LEFT,
			"KEY_RIGHT": KEY_RIGHT,
			"KEY_UP": KEY_UP,
			"KEY_DOWN": KEY_DOWN,
			"KEY_SHIFT": KEY_SHIFT,
			"KEY_CTRL": KEY_CTRL,
			"KEY_ALT": KEY_ALT,
			"KEY_0": KEY_0,
			"KEY_1": KEY_1,
			"KEY_2": KEY_2,
			"KEY_3": KEY_3,
			"KEY_4": KEY_4,
			"KEY_5": KEY_5,
			"KEY_6": KEY_6,
			"KEY_7": KEY_7,
			"KEY_8": KEY_8,
			"KEY_9": KEY_9
		}
	
	if constant_type == "all" or constant_type == "mouse":
		result["mouse_buttons"] = {
			"MOUSE_BUTTON_LEFT": MOUSE_BUTTON_LEFT,
			"MOUSE_BUTTON_RIGHT": MOUSE_BUTTON_RIGHT,
			"MOUSE_BUTTON_MIDDLE": MOUSE_BUTTON_MIDDLE,
			"MOUSE_BUTTON_WHEEL_UP": MOUSE_BUTTON_WHEEL_UP,
			"MOUSE_BUTTON_WHEEL_DOWN": MOUSE_BUTTON_WHEEL_DOWN
		}
	
	if constant_type == "all" or constant_type == "joypad":
		result["joypad_buttons"] = {
			"JOY_BUTTON_A": JOY_BUTTON_A,
			"JOY_BUTTON_B": JOY_BUTTON_B,
			"JOY_BUTTON_X": JOY_BUTTON_X,
			"JOY_BUTTON_Y": JOY_BUTTON_Y,
			"JOY_BUTTON_BACK": JOY_BUTTON_BACK,
			"JOY_BUTTON_START": JOY_BUTTON_START,
			"JOY_BUTTON_LEFT_SHOULDER": JOY_BUTTON_LEFT_SHOULDER,
			"JOY_BUTTON_RIGHT_SHOULDER": JOY_BUTTON_RIGHT_SHOULDER
		}
		result["joypad_axes"] = {
			"JOY_AXIS_LEFT_X": JOY_AXIS_LEFT_X,
			"JOY_AXIS_LEFT_Y": JOY_AXIS_LEFT_Y,
			"JOY_AXIS_RIGHT_X": JOY_AXIS_RIGHT_X,
			"JOY_AXIS_RIGHT_Y": JOY_AXIS_RIGHT_Y,
			"JOY_AXIS_TRIGGER_LEFT": JOY_AXIS_TRIGGER_LEFT,
			"JOY_AXIS_TRIGGER_RIGHT": JOY_AXIS_TRIGGER_RIGHT
		}
	
	return result
