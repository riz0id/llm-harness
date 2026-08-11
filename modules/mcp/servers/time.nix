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

  config = lib.mkIf (config.programs.claude-code.enable && config.tooling.mcp.time.enable) {
    # getExe' rather than getExe: the pinned nixpkgs ships mcp-server-time
    # with meta.mainProgram mistakenly set to "mcp-server-git".
    tooling.mcp.servers.time.command = lib.getExe' pkgs.mcp-server-time "mcp-server-time";

    programs.claude-code.settings.permissions.allow = map (helpers.claude-mcp-tool "time") [
      "get_current_time"
      "convert_time"
    ];
  };
}
