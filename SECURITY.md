# Security Best Practices

## Overview

The Godot MCP Server Plugin provides powerful access to your Godot editor and project files. While designed for local development with AI assistants, it's important to understand the security implications.

## Default Security Measures

### Localhost Only
- The server binds to `127.0.0.1` (localhost) by default
- This prevents remote access from other machines on your network
- Only applications running on your computer can connect

### No Authentication by Default
- The default configuration has no authentication
- This is acceptable for local development
- Consider enabling authentication for shared environments

## Recommended Practices

### 1. Use Authentication Tokens

Enable authentication in **Editor → Editor Settings → MCP Server**:

```
mcp_server/auth_token = "your-secret-token-here"
```

When enabled, clients must include the token in their requests.

### 2. Never Expose to Internet

**⚠️ CRITICAL**: Do not expose this server to the internet:
- Do not forward the port through your router
- Do not bind to `0.0.0.0` or public interfaces
- Do not use this on cloud instances without proper firewall rules

### 3. Understand Script Execution Risks

The `execute_gdscript` tool:
- Compiles GDScript code
- Does not execute arbitrary code in the current implementation
- Future versions may add execution capabilities
- Consider disabling this tool if concerned

### 4. Monitor Server Activity

The plugin logs all operations to the Godot console:
- Review logs regularly
- Look for unexpected or suspicious activity
- Disable the plugin when not actively using it

### 5. Use in Development Environments Only

This plugin is designed for development:
- Do not include it in production game builds
- Disable before exporting your game
- Keep it in the `addons/` directory (not exported by default)

### 6. Limit Network Access

Consider using a firewall to:
- Restrict which processes can access the port
- Allow only trusted MCP clients
- Block unexpected connections

## Threat Model

### What This Plugin Protects Against
- Remote access (binds to localhost only)
- Accidental exposure (not included in game exports)

### What This Plugin Does NOT Protect Against
- Malicious software running on your computer
- Compromised MCP clients
- Social engineering attacks
- Physical access to your machine

## Potential Risks

### 1. Code Execution
Tools can modify your project files, create/delete nodes, and execute scripts. A compromised MCP client could:
- Modify game logic
- Delete important nodes
- Inject malicious code

### 2. Data Exposure
The server can read:
- All project files
- Scene structures
- Script source code
- Resource contents

### 3. Project Manipulation
Clients can:
- Create/delete resources
- Modify scene trees
- Change node properties
- Attach/detach scripts

## Mitigation Strategies

### For Individual Developers
1. Use authentication tokens
2. Only run when actively developing with AI assistance
3. Review changes made by AI agents
4. Use version control (git) to track changes
5. Regular backups of your project

### For Team Environments
1. Enable authentication tokens
2. Use separate tokens per developer
3. Audit logs regularly
4. Implement additional firewall rules
5. Consider network segmentation

### For CI/CD Pipelines
**DO NOT** use this plugin in CI/CD:
- Not designed for automated environments
- Could expose your pipeline to risks
- Use proper Godot headless builds instead

## Incident Response

If you suspect unauthorized access:

1. **Immediately disable the plugin**
   - Go to Project Settings → Plugins
   - Uncheck "MCP Server"

2. **Check your project history**
   - Use `git log` to review recent changes
   - Look for unexpected modifications
   - Review the Godot console logs

3. **Restore from backup if needed**
   - Use version control to revert changes
   - Restore from file system backups

4. **Change authentication tokens**
   - Generate new secure tokens
   - Update all MCP client configurations

5. **Review system security**
   - Scan for malware
   - Check for unauthorized software
   - Review firewall rules

## Reporting Security Issues

If you discover a security vulnerability:

1. Do not open a public issue
2. Contact the maintainer directly
3. Provide details about the vulnerability
4. Allow time for a fix before public disclosure

## Updates and Patches

- Keep the plugin updated to the latest version
- Review changelogs for security fixes
- Subscribe to security advisories

## Compliance

If you work in a regulated industry:
- Consult your security team before using this plugin
- Ensure it meets your organization's policies
- Document its use in your security assessments
- Consider additional controls as needed

## Additional Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Godot Engine Security](https://docs.godotengine.org/en/stable/contributing/development/core_and_modules/security.html)
- [Model Context Protocol Specification](https://modelcontextprotocol.io/)

---

**Remember**: Security is a shared responsibility. This plugin provides the foundation, but you must use it safely and responsibly.
