# Batteries-included entry point: claude-code and codex with baked-in policy
# plus every MCP server enabled. Consumers set machine-specific values, most
# importantly `tooling.mcp.filesystem.directories'.

{ ... }:

{
  imports = [
    ./claude-code
    ./codex
    ./mcp
  ];

  tooling.mcp = {
    fetch.enable = true;

    filesystem.enable = true;

    git.enable = true;

    github.enable = true;

    nixos.enable = true;

    serena.enable = true;

    time.enable = true;
  };
}
