#!/bin/bash
# Setup script to copy the MCP Server plugin into the example project

PLUGIN_SRC="./addons/mcp_server"
PLUGIN_DEST="./example_project/addons/mcp_server"

# Create addons directory if it doesn't exist
mkdir -p ./example_project/addons

# Copy the plugin
if [ -d "$PLUGIN_SRC" ]; then
    echo "Copying MCP Server plugin to example project..."
    cp -r "$PLUGIN_SRC" "$PLUGIN_DEST"
    echo "Done! The example project now has the MCP Server plugin installed."
    echo "You can open ./example_project in Godot Engine."
else
    echo "Error: Plugin source not found at $PLUGIN_SRC"
    exit 1
fi
