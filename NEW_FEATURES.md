# New Features: Project Configuration, Input Maps, and Input Events

This document describes the new capabilities added to the Godot MCP Server Plugin.

## Overview

Three new tool categories have been added:

1. **Project Configuration Tools** - Get and set project settings
2. **Input Map Tools** - Manage input actions and key bindings
3. **Input Event Tools** - Send simulated input to running games

## Use Cases

### Automated Testing
Send simulated keyboard, mouse, and gamepad input to test game mechanics without manual interaction:
```json
// Start the game
{"name": "godot_game_play_scene", "arguments": {}}

// Send a jump input
{"name": "godot_input_send_action", "arguments": {"action_name": "jump", "pressed": true}}

// Send arrow key input
{"name": "godot_input_send_key", "arguments": {"keycode": 16777231, "pressed": true}}
```

### Dynamic Configuration
Modify project settings and input bindings programmatically:
```json
// Change window size
{"name": "godot_project_set_setting", "arguments": {
  "setting_name": "display/window/size/width",
  "value": 1920
}}

// Add a new input action
{"name": "godot_input_add_action", "arguments": {"action_name": "custom_action"}}

// Bind Space key to the action
{"name": "godot_input_add_event", "arguments": {
  "action_name": "custom_action",
  "event": {"type": "key", "keycode": 32, "pressed": true}
}}
```

### AI-Assisted Development
Allow AI agents to:
- Inspect and modify project configuration
- Set up input schemes for different control types (keyboard, gamepad, touch)
- Test game behavior by simulating player input
- Debug input handling by checking action mappings

### Input Remapping Tools
Build in-game settings systems by:
- Reading current input mappings
- Modifying bindings based on player preferences
- Validating key conflicts

## Project Configuration Tools

### godot_project_get_setting
Get any project setting value from project.godot.

**Example:**
```json
{
  "name": "godot_project_get_setting",
  "arguments": {
    "setting_name": "application/config/name"
  }
}
```

### godot_project_set_setting
Modify project settings and save to disk.

**Example:**
```json
{
  "name": "godot_project_set_setting",
  "arguments": {
    "setting_name": "display/window/size/width",
    "value": 1920
  }
}
```

### godot_project_list_settings
List all or filtered project settings.

**Example:**
```json
{
  "name": "godot_project_list_settings",
  "arguments": {
    "prefix": "display/"
  }
}
```

## Input Map Tools

### godot_input_list_actions
Get all input actions and their bindings.

### godot_input_add_action
Create new input actions.

### godot_input_add_event
Bind keys/buttons to actions.

**Example - Complete input setup:**
```json
// 1. Create action
{"name": "godot_input_add_action", "arguments": {"action_name": "shoot"}}

// 2. Add Space key binding
{"name": "godot_input_add_event", "arguments": {
  "action_name": "shoot",
  "event": {"type": "key", "keycode": 32, "pressed": true}
}}

// 3. Add left mouse button binding
{"name": "godot_input_add_event", "arguments": {
  "action_name": "shoot",
  "event": {"type": "mouse_button", "button_index": 1, "pressed": true}
}}
```

## Input Event Tools

### godot_input_send_action
Simulate action input (highest level).

**Example:**
```json
{
  "name": "godot_input_send_action",
  "arguments": {
    "action_name": "jump",
    "pressed": true
  }
}
```

### godot_input_send_key
Simulate keyboard input.

**Example:**
```json
{
  "name": "godot_input_send_key",
  "arguments": {
    "keycode": 87,  // W key
    "pressed": true
  }
}
```

### godot_input_send_mouse_button
Simulate mouse clicks.

**Example:**
```json
{
  "name": "godot_input_send_mouse_button",
  "arguments": {
    "button_index": 1,  // Left mouse button
    "pressed": true,
    "position_x": 512.0,
    "position_y": 384.0
  }
}
```

### godot_input_send_joypad_button
Simulate gamepad buttons.

**Example:**
```json
{
  "name": "godot_input_send_joypad_button",
  "arguments": {
    "button_index": 0,  // A button
    "pressed": true
  }
}
```

### godot_input_get_constants
Get key/button code constants.

**Example:**
```json
{
  "name": "godot_input_get_constants",
  "arguments": {
    "type": "keys"
  }
}
```

Returns:
```json
{
  "keys": {
    "KEY_SPACE": 32,
    "KEY_ENTER": 10,
    "KEY_W": 87,
    "KEY_LEFT": 16777231,
    ...
  }
}
```

## Testing

A comprehensive test script is provided:

```bash
python3 test_new_features.py
```

This tests:
- Project configuration reading/writing
- Input action creation and management
- Input event binding
- Input simulation
- Constant retrieval

## Implementation Details

### New Tool Modules

Three new GDScript modules were added to `addons/mcp_server/tools/`:

1. **project_tools.gd** - Project configuration management
2. **input_map_tools.gd** - Input action and mapping management
3. **input_event_tools.gd** - Input event simulation

### Integration

The tools are integrated into `mcp_protocol.gd`:
- Tool schemas added to `_handle_tools_list()`
- Tool handlers added to `_handle_tools_call()`
- Module references initialized in `_init()`

### Type Conversion

The tools properly handle Godot type conversions:
- Vector2/Vector3 ↔ JSON objects/arrays
- Color ↔ JSON objects with RGBA values
- Input events ↔ Structured dictionaries

### Persistence

- Project settings are automatically saved to project.godot
- Input map changes are persisted to project settings
- All changes survive editor restart

## Limitations

1. **Input events** only affect running games/scenes, not the editor itself
2. **Project settings** changes may require editor restart for some settings
3. **Input simulation** timing is immediate - no replay or timing control (yet)
4. Some project settings are read-only and cannot be modified

## Future Enhancements

Potential additions:
- Input event recording and replay
- Macro/script support for complex input sequences
- Timing control for input events
- Touch input simulation
- Input action validation and conflict detection
- Export preset configuration tools

## Security Considerations

- Project settings modifications can break projects if invalid values are used
- Input simulation only works on localhost by default
- All changes are logged to the Godot console
- Consider authentication if exposing the server beyond localhost

## Documentation Updates

- README.md - Updated with new tool descriptions
- API_REFERENCE.md - Complete API documentation for new tools
- CHANGELOG.md - New features documented in [Unreleased] section

## Example Workflows

### Setup Custom Controls
```python
# Create movement actions
add_action("move_up")
add_action("move_down")
add_action("move_left")
add_action("move_right")

# Bind WASD keys
add_event("move_up", {"type": "key", "keycode": KEY_W})
add_event("move_down", {"type": "key", "keycode": KEY_S})
add_event("move_left", {"type": "key", "keycode": KEY_A})
add_event("move_right", {"type": "key", "keycode": KEY_D})

# Also bind arrow keys
add_event("move_up", {"type": "key", "keycode": KEY_UP})
add_event("move_down", {"type": "key", "keycode": KEY_DOWN})
add_event("move_left", {"type": "key", "keycode": KEY_LEFT})
add_event("move_right", {"type": "key", "keycode": KEY_RIGHT})
```

### Automated Game Testing
```python
# Start game
play_scene()

# Wait for game to load (external timing)
time.sleep(2)

# Simulate player movement
send_action("move_right", pressed=True)
time.sleep(1)
send_action("move_right", pressed=False)

# Jump
send_action("jump", pressed=True)
time.sleep(0.1)
send_action("jump", pressed=False)

# Check output for errors
output = get_editor_output(filter_text="error")
```

## Compatibility

- Requires Godot 4.x
- Compatible with both 2D and 3D projects
- Works with the existing MCP server infrastructure
- No breaking changes to existing tools
