# Quick Start Guide

Get up and running with the Godot MCP Server Plugin in 5 minutes.

## Step 1: Install the Plugin

1. Copy the `addons/mcp_server/` directory to your Godot project's `addons/` folder
2. Open your project in Godot Engine 4.x
3. Go to **Project → Project Settings → Plugins**
4. Enable "MCP Server"

✅ You should see "MCP Server started on port 8765" in the Output console.

## Step 2: Test the Server

Open a terminal and run:

```bash
curl -X POST http://localhost:8765 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}'
```

Expected response:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "protocolVersion": "2024-11-05",
    "capabilities": {...},
    "serverInfo": {...}
  },
  "id": 1
}
```

## Step 3: Configure Claude Desktop

1. Locate your Claude Desktop configuration file:
   - **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
   - **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
   - **Linux**: `~/.config/Claude/claude_desktop_config.json`

2. Add this configuration:

```json
{
  "mcpServers": {
    "godot": {
      "url": "http://localhost:8765",
      "transport": {
        "type": "http"
      }
    }
  }
}
```

3. Restart Claude Desktop

## Step 4: Try It Out with Claude

Open Claude Desktop and try these prompts:

### Example 1: Inspect Scene
```
What nodes are in my current Godot scene?
```

Claude will use the `get_scene_tree` tool to show you the scene structure.

### Example 2: Create a Node
```
Create a new Sprite2D node named "Player" under the root node.
```

Claude will use the `create_node` tool to add the node.

### Example 3: Modify Properties
```
Set the position of the Player node to (200, 150).
```

Claude will use the `set_node_property` tool to update the position.

### Example 4: Get a Screenshot
```
Show me what the current scene looks like.
```

Claude will use the `get_screenshot` tool to capture the viewport.

## Step 5: Verify Changes

1. Look at your Godot editor
2. You should see the changes Claude made
3. Check the Scene dock to see new nodes
4. Verify properties in the Inspector

## Common First Commands

Here are some useful commands to try with Claude:

- "List all the tools you can use in Godot"
- "What scene is currently open?"
- "Create a test scene with a player, enemy, and camera"
- "Show me the properties of the root node"
- "What resources are in my project?"

## Troubleshooting

### "Connection refused" error
- Make sure Godot is running
- Check that the plugin is enabled
- Verify the server started (check Output console)

### "No scene is currently open"
- Open or create a scene in Godot
- Save the scene (Ctrl+S / Cmd+S)

### Claude can't see the Godot server
- Restart Claude Desktop after changing the config
- Check the config file path is correct
- Verify the JSON syntax is valid

### Changes aren't appearing
- Check the Output console for errors
- Verify node paths are correct (case-sensitive)
- Try saving the scene in Godot

## Next Steps

- Read the full [README.md](README.md) for all available tools
- Review [SECURITY.md](SECURITY.md) for security best practices
- Check the [example_project/](example_project/) for a working setup
- Experiment with different tools and workflows

## Advanced Usage

### Custom Port

Change the port in **Editor → Editor Settings → MCP Server → Port**, then update your MCP configuration:

```json
{
  "mcpServers": {
    "godot": {
      "url": "http://localhost:9000",
      ...
    }
  }
}
```

### Authentication

1. Set a token in **Editor → Editor Settings → MCP Server → Auth Token**
2. Update your requests to include the token (implementation TBD)

### Multiple Projects

You can run multiple Godot instances with different ports:

```json
{
  "mcpServers": {
    "godot-project1": {
      "url": "http://localhost:8765",
      ...
    },
    "godot-project2": {
      "url": "http://localhost:8766",
      ...
    }
  }
}
```

## Getting Help

- Check the Output console in Godot for error messages
- Review the tool documentation in README.md
- Ensure you're using Godot 4.x
- Verify your MCP client supports HTTP transport

Happy AI-assisted game development! 🎮🤖
