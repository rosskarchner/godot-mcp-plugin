#!/usr/bin/env python3
"""
Test script for new MCP Server features:
- Project configuration tools
- Input map tools  
- Input event tools

Make sure Godot is running with the plugin enabled before running this.

Usage:
    python3 test_new_features.py [--port 8765]
"""

import json
import sys
import argparse
import urllib.request
import urllib.error

def make_request(url, method, params=None, request_id=1):
    """Make a JSON-RPC request to the server."""
    data = {
        "jsonrpc": "2.0",
        "method": method,
        "params": params if params is not None else {},
        "id": request_id
    }
    
    json_data = json.dumps(data).encode('utf-8')
    
    try:
        req = urllib.request.Request(
            url,
            data=json_data,
            headers={'Content-Type': 'application/json'}
        )
        
        with urllib.request.urlopen(req, timeout=5) as response:
            return json.loads(response.read().decode('utf-8'))
    except urllib.error.URLError as e:
        return {"error": f"Connection failed: {e}"}
    except Exception as e:
        return {"error": f"Request failed: {e}"}

def call_tool(server_url, tool_name, arguments=None):
    """Call an MCP tool."""
    return make_request(server_url, "tools/call", {
        "name": tool_name,
        "arguments": arguments if arguments is not None else {}
    })

def print_result(test_name, result):
    """Print a test result."""
    print(f"\n{'='*60}")
    print(f"Test: {test_name}")
    print(f"{'='*60}")
    if "error" in result:
        print(f"❌ ERROR: {result['error']}")
    elif "result" in result:
        print("✅ SUCCESS")
        print(json.dumps(result["result"], indent=2))
    else:
        print(json.dumps(result, indent=2))

def main():
    parser = argparse.ArgumentParser(description='Test Godot MCP Server new features')
    parser.add_argument('--port', type=int, default=8765, help='Server port (default: 8765)')
    args = parser.parse_args()
    
    server_url = f"http://localhost:{args.port}"
    
    print("🧪 Testing Godot MCP Server New Features")
    print(f"Server URL: {server_url}\n")
    
    # Test 1: List tools to verify new tools are registered
    print_result("List Tools", make_request(server_url, "tools/list"))
    
    # Test 2: Project Configuration Tools
    print("\n" + "="*70)
    print("PROJECT CONFIGURATION TESTS")
    print("="*70)
    
    # Get project name
    result = call_tool(server_url, "godot_project_get_setting", {
        "setting_name": "application/config/name"
    })
    print_result("Get Project Name", result)
    
    # List application settings
    result = call_tool(server_url, "godot_project_list_settings", {
        "prefix": "application/"
    })
    print_result("List Application Settings", result)
    
    # Test 3: Input Map Tools
    print("\n" + "="*70)
    print("INPUT MAP TESTS")
    print("="*70)
    
    # List all input actions
    result = call_tool(server_url, "godot_input_list_actions")
    print_result("List Input Actions", result)
    
    # Add a test action
    result = call_tool(server_url, "godot_input_add_action", {
        "action_name": "test_action",
        "deadzone": 0.5
    })
    print_result("Add Test Action", result)
    
    # Get constants for key codes
    result = call_tool(server_url, "godot_input_get_constants", {
        "type": "keys"
    })
    print_result("Get Key Constants", result)
    
    # Add a key event to the test action (Space key)
    if "result" in result and "content" in result["result"]:
        try:
            content_text = result["result"]["content"][0]["text"]
            constants = json.loads(content_text)
            if "keys" in constants and "KEY_SPACE" in constants["keys"]:
                key_space = constants["keys"]["KEY_SPACE"]
                
                result = call_tool(server_url, "godot_input_add_event", {
                    "action_name": "test_action",
                    "event": {
                        "type": "key",
                        "keycode": key_space,
                        "pressed": True
                    }
                })
                print_result("Add Space Key to Test Action", result)
        except:
            pass
    
    # Get the test action details
    result = call_tool(server_url, "godot_input_get_action", {
        "action_name": "test_action"
    })
    print_result("Get Test Action Details", result)
    
    # Test 4: Input Event Tools
    print("\n" + "="*70)
    print("INPUT EVENT TESTS")
    print("="*70)
    
    # Note: These will only work if a scene is running
    print("Note: Input event tests require a running scene.")
    print("These will be sent but may not have visible effect without a running game.")
    
    # Send a key event
    result = call_tool(server_url, "godot_input_send_key", {
        "keycode": 32,  # Space key
        "pressed": True
    })
    print_result("Send Space Key Press", result)
    
    # Send a mouse button event
    result = call_tool(server_url, "godot_input_send_mouse_button", {
        "button_index": 1,  # Left mouse button
        "pressed": True,
        "position_x": 100.0,
        "position_y": 100.0
    })
    print_result("Send Mouse Click", result)
    
    # Get mouse button constants
    result = call_tool(server_url, "godot_input_get_constants", {
        "type": "mouse"
    })
    print_result("Get Mouse Constants", result)
    
    # Cleanup: Remove the test action
    print("\n" + "="*70)
    print("CLEANUP")
    print("="*70)
    
    result = call_tool(server_url, "godot_input_remove_action", {
        "action_name": "test_action"
    })
    print_result("Remove Test Action", result)
    
    print("\n" + "="*70)
    print("✅ All tests completed!")
    print("="*70)

if __name__ == "__main__":
    main()
