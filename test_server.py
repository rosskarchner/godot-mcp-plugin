#!/usr/bin/env python3
"""
Test script for Godot MCP Server

This script tests basic functionality of the MCP server.
Make sure Godot is running with the plugin enabled before running this.

Usage:
    python3 test_server.py [--port 8765]
"""

import json
import sys
import argparse
import urllib.request
import urllib.error

class Colors:
    BLUE = '\033[0;34m'
    GREEN = '\033[0;32m'
    RED = '\033[0;31m'
    YELLOW = '\033[0;33m'
    NC = '\033[0m'

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

def test_initialize(server_url):
    """Test 1: Initialize"""
    print(f"{Colors.BLUE}Test 1: Initialize{Colors.NC}")
    response = make_request(server_url, "initialize", {}, 1)
    
    if "result" in response and "protocolVersion" in response["result"]:
        print(f"{Colors.GREEN}✓ Initialize successful{Colors.NC}")
        print(f"  Protocol version: {response['result']['protocolVersion']}")
        print(f"  Server: {response['result']['serverInfo']['name']} v{response['result']['serverInfo']['version']}\n")
        return True
    else:
        print(f"{Colors.RED}✗ Initialize failed{Colors.NC}")
        print(f"  Response: {json.dumps(response, indent=2)}\n")
        return False

def test_tools_list(server_url):
    """Test 2: List tools"""
    print(f"{Colors.BLUE}Test 2: List tools{Colors.NC}")
    response = make_request(server_url, "tools/list", {}, 2)
    
    if "result" in response and "tools" in response["result"]:
        tools = response["result"]["tools"]
        print(f"{Colors.GREEN}✓ Tools list successful{Colors.NC}")
        print(f"  Found {len(tools)} tools:")
        for tool in tools[:5]:  # Show first 5
            print(f"    - {tool['name']}")
        if len(tools) > 5:
            print(f"    ... and {len(tools) - 5} more\n")
        else:
            print()
        return True
    else:
        print(f"{Colors.RED}✗ Tools list failed{Colors.NC}")
        print(f"  Response: {json.dumps(response, indent=2)}\n")
        return False

def test_get_current_scene(server_url):
    """Test 3: Get current scene"""
    print(f"{Colors.BLUE}Test 3: Get current scene{Colors.NC}")
    response = make_request(
        server_url,
        "tools/call",
        {"name": "get_current_scene", "arguments": {}},
        3
    )
    
    if "result" in response:
        result = response["result"]
        if "error" in result:
            print(f"{Colors.YELLOW}⚠ No scene open{Colors.NC}")
            print(f"  Message: {result['error']}\n")
        else:
            print(f"{Colors.GREEN}✓ Get current scene successful{Colors.NC}")
            print(f"  Scene: {result.get('path', 'N/A')}")
            print(f"  Name: {result.get('name', 'N/A')}\n")
        return True
    else:
        print(f"{Colors.RED}✗ Get current scene failed{Colors.NC}")
        print(f"  Response: {json.dumps(response, indent=2)}\n")
        return False

def test_list_resources(server_url):
    """Test 4: List resources"""
    print(f"{Colors.BLUE}Test 4: List resources{Colors.NC}")
    response = make_request(server_url, "resources/list", {}, 4)
    
    if "result" in response and "resources" in response["result"]:
        resources = response["result"]["resources"]
        print(f"{Colors.GREEN}✓ List resources successful{Colors.NC}")
        print(f"  Found {len(resources)} resources")
        
        # Count by type
        types = {}
        for res in resources:
            res_type = res.get("mimeType", "unknown")
            types[res_type] = types.get(res_type, 0) + 1
        
        print("  Types:")
        for mime_type, count in sorted(types.items())[:5]:
            print(f"    - {mime_type}: {count}")
        print()
        return True
    else:
        print(f"{Colors.RED}✗ List resources failed{Colors.NC}")
        print(f"  Response: {json.dumps(response, indent=2)}\n")
        return False

def test_editor_output(server_url):
    """Test 6: Get editor output"""
    print(f"{Colors.BLUE}Test 6: Get editor output{Colors.NC}")
    response = make_request(
        server_url, 
        "tools/call", 
        {
            "name": "godot_editor_get_output",
            "arguments": {"max_lines": 20}
        }, 
        6
    )
    
    if "result" in response:
        result = response["result"]
        if "success" in result and result["success"]:
            print(f"{Colors.GREEN}✓ Editor output retrieved{Colors.NC}")
            print(f"  Total lines: {result.get('total_lines', 0)}")
            print(f"  Log path: {result.get('log_path', 'N/A')}")
            if result.get('lines') and len(result['lines']) > 0:
                print(f"  Sample (first 3 lines):")
                for line in result['lines'][:3]:
                    print(f"    {line[:80]}")  # Truncate long lines
            print()
            return True
        else:
            print(f"{Colors.YELLOW}⚠ Editor output tool returned an error{Colors.NC}")
            print(f"  Response: {json.dumps(result, indent=2)}\n")
            return True  # Tool exists but may not have logs yet
    else:
        print(f"{Colors.RED}✗ Editor output test failed{Colors.NC}")
        print(f"  Response: {json.dumps(response, indent=2)}\n")
        return False

def test_error_handling(server_url):
    """Test 7: Invalid method (error handling)"""
    print(f"{Colors.BLUE}Test 7: Invalid method (error handling){Colors.NC}")
    response = make_request(server_url, "invalid_method", {}, 5)
    
    if "error" in response:
        print(f"{Colors.GREEN}✓ Error handling works{Colors.NC}")
        print(f"  Error code: {response['error']['code']}")
        print(f"  Message: {response['error']['message']}\n")
        return True
    else:
        print(f"{Colors.RED}✗ Error handling failed{Colors.NC}")
        print(f"  Response: {json.dumps(response, indent=2)}\n")
        return False

def main():
    parser = argparse.ArgumentParser(description='Test Godot MCP Server')
    parser.add_argument('--port', type=int, default=8765, help='Server port (default: 8765)')
    parser.add_argument('--host', type=str, default='localhost', help='Server host (default: localhost)')
    args = parser.parse_args()
    
    server_url = f"http://{args.host}:{args.port}"
    
    print(f"{Colors.BLUE}=== Godot MCP Server Test Suite ==={Colors.NC}")
    print(f"Testing server at: {server_url}\n")
    
    tests = [
        test_initialize,
        test_tools_list,
        test_get_current_scene,
        test_list_resources,
        test_editor_output,
        test_error_handling
    ]
    
    passed = 0
    failed = 0
    
    for test in tests:
        try:
            if test(server_url):
                passed += 1
            else:
                failed += 1
        except Exception as e:
            print(f"{Colors.RED}✗ Test crashed: {e}{Colors.NC}\n")
            failed += 1
    
    print(f"{Colors.BLUE}=== Test Suite Complete ===${Colors.NC}")
    print(f"{Colors.GREEN}Passed: {passed}{Colors.NC}")
    print(f"{Colors.RED}Failed: {failed}{Colors.NC}\n")
    
    if failed > 0:
        print(f"{Colors.YELLOW}Note: Some tests may fail if no scene is open in Godot.{Colors.NC}")
        print(f"{Colors.YELLOW}Open a scene in the Godot editor and run this script again.{Colors.NC}\n")
    
    return 0 if failed == 0 else 1

if __name__ == "__main__":
    sys.exit(main())
