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
  options.tooling.mcp.time = lib.mkOption {
    description = "The 'time' MCP server.";

    default = { };

    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "time";
      };
    };
  };

  config = lib.mkIf config.tooling.mcp.time.enable (
    lib.mkMerge [
      {
        # getExe' rather than getExe: the pinned nixpkgs ships mcp-server-time
        # with meta.mainProgram mistakenly set to "mcp-server-git".
        tooling.mcp.servers.time.command = lib.getExe' pkgs.mcp-server-time "mcp-server-time";
      }

      (lib.mkIf config.programs.claude-code.enable {
        programs.claude-code.settings.permissions.allow = map (helpers.claude-mcp-tool "time") [
          "get_current_time"
          "convert_time"
        ];
      })

      (lib.mkIf config.programs.codex.enable {
        programs.codex.settings.mcp_servers.time.default_tools_approval_mode = "auto";
      })
    ]
  );
}
