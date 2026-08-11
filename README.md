
***ENTIRELY LLM GENERATED!***

# llm-harness

Claude Code and MCP server configuration packaged as reusable home-manager
modules, with the supporting packages (`gh-mcp`, `mcp-nixos`, `sash`,
`claude-command-log`, `llm-hooks`) built from this flake.

## Usage

Add the flake as an input to a NixOS (or nix-darwin) system configuration:

```nix
inputs.llm-harness = {
  url = "git+file:///Users/jake/Documents/Programming/Nix/llm-harness";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Import the default module into a home-manager user (via home-manager's NixOS
module, darwin module, or standalone):

```nix
home-manager.users.<name> = {
  imports = [ inputs.llm-harness.homeModules.default ];

  # Machine-specific: directories the filesystem MCP server may access.
  tooling.mcp.filesystem.directories = [
    "/nix/store"
    "/home/<name>/Documents/Programming"
  ];
};
```

`homeModules.default` enables claude-code (with baked-in model, permissions,
hooks, and context) and every MCP server: `fetch`, `filesystem`, `git`,
`github`, `nixos`, `time`. Import `homeModules.claude-code` or
`homeModules.mcp` individually to pick servers by hand via
`tooling.mcp.<server>.enable`.

## Requirements

- home-manager with the upstream `programs.claude-code` module (all MCP
  wiring is gated on `programs.claude-code.enable`).
- `nixpkgs.config.allowUnfree = true` for the `claude-code` and `terraform`
  packages.
- `tooling.mcp.filesystem.directories` must be non-empty when the filesystem
  server is enabled; the server exits without any permitted directories.

## Other outputs

- `packages.<system>.{gh-mcp,mcp-nixos,sash,claude-command-log,llm-hooks}`
- `overlays.default` — adds the packages above to `pkgs` (flat attribute
  names). The modules do not require the overlay; they build their own copies
  via `callPackage`.
- `lib.{claude-mcp-tool,claude-deny-bash-hook}` — helpers for writing
  additional permission rules and deny-hooks in consumer configuration.
