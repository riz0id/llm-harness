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

  config = lib.mkIf (config.programs.claude-code.enable && config.tooling.mcp.fetch.enable) {
    tooling.mcp.servers.fetch.command = lib.getExe pkgs.mcp-server-fetch;

    programs.claude-code.settings.permissions.allow = [
      (helpers.claude-mcp-tool "fetch" "fetch")
    ];
  };
}
