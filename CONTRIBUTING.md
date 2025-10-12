# Contributing to Godot MCP Server Plugin

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## How to Contribute

### Reporting Bugs

If you find a bug:

1. Check if the issue already exists in the [Issues](https://github.com/rosskarchner/godot-mcp-plugin/issues)
2. If not, create a new issue with:
   - Clear description of the bug
   - Steps to reproduce
   - Expected vs actual behavior
   - Godot version
   - Operating system
   - Relevant logs from the Godot console

### Suggesting Features

Feature suggestions are welcome! Please:

1. Check existing issues and discussions
2. Create a new issue with:
   - Clear description of the feature
   - Use cases and benefits
   - Potential implementation approach (optional)
   - MCP specification compatibility considerations

### Submitting Pull Requests

1. **Fork the repository** and create a branch from `main`
2. **Make your changes** following the code style guidelines
3. **Test your changes** thoroughly
4. **Update documentation** if needed
5. **Write clear commit messages**
6. **Submit a pull request** with:
   - Description of changes
   - Related issue numbers (if any)
   - Testing performed

## Development Setup

1. Clone the repository
2. Open the `example_project` in Godot 4.x
3. The plugin should be automatically enabled
4. Test your changes in the editor

## Code Style Guidelines

### GDScript Style

Follow the [Godot GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html):

- Use **snake_case** for variables and functions
- Use **PascalCase** for class names and constants
- Use **tabs** for indentation
- Add **type hints** to all variables and function parameters
- Use **docstrings** (##) for classes and public methods

Example:
```gdscript
## Brief description
##
## Detailed description if needed
func my_function(param: int) -> String:
	var result: String = "Hello"
	return result
```

### File Organization

- Keep files focused on a single responsibility
- Use the existing directory structure
- Place tools in `tools/` directory
- Keep utilities separate from core functionality

### Comments

- Use `##` for documentation comments
- Use `#` for inline comments
- Document complex logic
- Don't comment obvious code

## Testing

Since this is a Godot plugin:

1. **Manual Testing**:
   - Test in Godot Editor with a real project
   - Verify all tools work as expected
   - Test error conditions
   - Check console output

2. **curl Testing**:
   - Test JSON-RPC requests with curl
   - Verify response formats
   - Test error responses

3. **MCP Client Testing**:
   - Test with Claude Desktop or other MCP clients
   - Verify tool schemas are correct
   - Test complex workflows

## Adding New Tools

To add a new tool:

1. **Add tool schema** in `mcp_protocol.gd`:
   ```gdscript
   tools.append(_create_tool_schema(
       "tool_name",
       "Tool description",
       {
           "type": "object",
           "properties": {
               "param_name": {
                   "type": "string",
                   "description": "Parameter description"
               }
           },
           "required": ["param_name"]
       }
   ))
   ```

2. **Add tool handler** in `mcp_protocol.gd`:
   ```gdscript
   match tool_name:
       "tool_name":
           result = module_tools.tool_function(arguments)
   ```

3. **Implement tool** in appropriate module:
   ```gdscript
   func tool_function(args: Dictionary) -> Dictionary:
       # Validate arguments
       if not args.has("param_name"):
           return {"error": "Missing required parameter: param_name"}
       
       # Implement functionality
       # ...
       
       # Return result
       return {
           "success": true,
           "result": "..."
       }
   ```

4. **Update documentation** in README.md

5. **Test thoroughly**

## Documentation

Good documentation is essential:

- Update README.md for new features
- Add examples for new tools
- Update CHANGELOG.md
- Keep QUICKSTART.md current
- Add security notes to SECURITY.md if needed

## Commit Messages

Use clear, descriptive commit messages:

```
Add get_node_transform tool

- Implement tool in node_tools.gd
- Add schema to mcp_protocol.gd
- Update documentation
```

Follow the pattern:
- First line: Brief summary (50 chars or less)
- Blank line
- Detailed description if needed (wrapped at 72 chars)

## Pull Request Process

1. Ensure your code follows the style guidelines
2. Update documentation
3. Test your changes
4. Create a pull request with:
   - Clear title
   - Description of changes
   - Related issues
   - Screenshots if applicable
5. Respond to review feedback
6. Ensure CI checks pass (if applicable)

## Code Review

Pull requests will be reviewed for:

- Code quality and style
- Functionality and correctness
- Documentation completeness
- Test coverage
- Security implications
- MCP specification compliance
- Performance considerations

## Community Guidelines

- Be respectful and constructive
- Follow the code of conduct
- Help others learn
- Give credit where due
- Focus on the issue, not the person

## Questions?

If you have questions:

1. Check existing documentation
2. Search closed issues
3. Open a new issue with the "question" label
4. Be specific and provide context

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Thank You!

Your contributions help make AI-assisted game development better for everyone. Thank you for your time and effort! 🎮🤖
