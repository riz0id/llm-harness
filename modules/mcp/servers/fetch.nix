{
  config,
  lib,
  pkgs,
  ...
}:

let
  helpers = import ../../../lib.nix { inherit lib; };
in
{
  options.tooling.mcp.fetch = lib.mkOption {
    description = "The 'fetch' MCP server.";

    default = { };

    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "fetch";
      };
    };
  };

  config = lib.mkIf config.tooling.mcp.fetch.enable (
    lib.mkMerge [
      {
        tooling.mcp.servers.fetch.command = lib.getExe pkgs.mcp-server-fetch;
      }

      (lib.mkIf config.programs.claude-code.enable {
        programs.claude-code.settings.permissions.allow = [
          (helpers.claude-mcp-tool "fetch" "fetch")
        ];
      })

      (lib.mkIf config.programs.codex.enable {
        programs.codex.settings.mcp_servers.fetch.default_tools_approval_mode = "auto";
      })
    ]
  );
}
