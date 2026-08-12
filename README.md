
***ENTIRELY LLM GENERATED!***

# llm-harness

Claude Code, Codex, and MCP server configuration packaged as reusable
home-manager modules, with the supporting packages (`gh-mcp`, `mcp-nixos`,
`sash`, `claude-command-log`, `llm-hooks`) built from this flake.

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

`homeModules.default` enables claude-code and codex (with baked-in
permissions, hooks, and context) and every MCP server: `fetch`, `filesystem`,
`git`, `github`, `nixos`, `serena`, `time`. Import `homeModules.claude-code`,
`homeModules.codex`, or `homeModules.mcp` individually to pick agents and
servers by hand via `tooling.mcp.<server>.enable`.

## How the two agents share configuration

- `tooling.context` collects agent-agnostic instruction text; it is written
  to Claude Code's managed CLAUDE.md and to Codex's `CODEX_HOME/AGENTS.md`.
- `tooling.mcp.servers` is the shared MCP registry. Claude Code receives it
  via a wrapped `claude --mcp-config`; Codex receives it natively as
  `mcp_servers` in `config.toml`.
- Claude Code's `permissions.allow`/`permissions.deny` (plus `denyAdvice`)
  map to Codex `prefix_rule(...)` entries in `CODEX_HOME/rules/llm-harness.rules`,
  with justifications carrying the redirect advice.
- Both agents log requested shell commands to
  `~/.claude/command-log.sqlite` via `claude-command-log`, and both run the
  `llm-hooks` post-edit formatter hook (`claude-post-edit` /
  `codex-post-edit`).

Known asymmetries:

- Claude Code's per-tool MCP allowlists become per-server
  `default_tools_approval_mode` settings for Codex (`auto` for read-only
  servers, `writes` for servers with mutating tools).
- The `sed -n M,Np` glob deny and sash's literal-only auto-allow proof are
  Claude-only; Codex's own trusted-command rules and sandbox
  (`sandbox_mode = "workspace-write"`, `approval_policy = "untrusted"`) fill
  that role.
- Codex has no `--add-dir` analogue; the filesystem server's directories come
  solely from its command-line arguments.
- The Codex model is not set by the harness; set
  `programs.codex.settings.model` (and `model_reasoning_effort`) as desired.

## Requirements

- home-manager with the upstream `programs.claude-code` and `programs.codex`
  modules (all MCP wiring is gated on the respective `enable`).
- `nixpkgs.config.allowUnfree = true` for the `claude-code` and `terraform`
  packages.
- `tooling.mcp.filesystem.directories` must be non-empty when the filesystem
  server is enabled; the server exits without any permitted directories.

## Other outputs

- `packages.<system>.{gh-mcp,mcp-nixos,sash,claude-command-log,llm-hooks}`
- `overlays.default` — adds the packages above to `pkgs` (flat attribute
  names). The modules do not require the overlay; they build their own copies
  via `callPackage`.
- `lib.{claude-mcp-tool,claude-deny-bash-hook,codex-prefix-rule}` — helpers
  for writing additional permission rules, deny-hooks, and Codex rules in
  consumer configuration.
