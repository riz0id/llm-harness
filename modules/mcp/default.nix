{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.tooling.mcp;

  mcpConfig = pkgs.writeText "claude-code-mcp.json" (builtins.toJSON { mcpServers = cfg.servers; });

  addDirFlags = lib.escapeShellArgs (
    lib.concatMap (dir: [
      "--add-dir"
      dir
    ]) (lib.unique cfg.addDirs)
  );

  mkWarning =
    name:
    lib.optional
      (cfg.${name}.enable && !config.programs.claude-code.enable && !config.programs.codex.enable)
      "The '${name}' MCP server is enabled without `programs.claude-code.enable = true' or `programs.codex.enable = true'.";
in
{
  imports = [
    ../common
    ./servers
  ];

  options.tooling.mcp.servers = lib.mkOption {
    description = "MCP server definitions passed to Claude Code via `--mcp-config'.";
    type = lib.types.attrsOf lib.types.anything;
    default = { };
  };

  options.tooling.mcp.addDirs = lib.mkOption {
    description = "Directories passed to Claude Code via `--add-dir' so they are advertised as MCP roots.";
    type = lib.types.listOf lib.types.str;
    default = [ ];
  };

  config = lib.mkMerge [
    {
      # Submodules cannot declare `warnings'; surface per-server warnings from
      # the top-level module, outside the mkIf below so they can actually fire.
      warnings = lib.concatMap mkWarning (
        lib.attrNames (
          builtins.removeAttrs cfg [
            "servers"
            "addDirs"
          ]
        )
      );
    }

    (lib.mkIf (config.programs.claude-code.enable && cfg.servers != { }) {
      # Wrapped with `--mcp-config' rather than forwarded to
      # `programs.claude-code.mcpServers': the home-manager MCP integration
      # packages servers into a plugin, namespacing tools as
      # `mcp__plugin_claude-code-home-manager_<server>__<tool>' and breaking
      # the short `mcp__<server>__<tool>' permission rules.
      programs.claude-code.package = pkgs.symlinkJoin {
        name = "claude-code-mcp";
        paths = [ pkgs.claude-code ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/claude \
            --inherit-argv0 \
            --add-flags "--mcp-config ${mcpConfig} ${addDirFlags}"
        '';
        inherit (pkgs.claude-code) meta;
      };
    })

    (lib.mkIf (config.programs.codex.enable && cfg.servers != { }) {
      # Codex reads MCP servers natively from config.toml; no wrapper needed.
      # Server modules layer codex-specific settings (approval modes, arg
      # overrides) on top of these entries.
      programs.codex.settings.mcp_servers = cfg.servers;
    })
  ];
}
