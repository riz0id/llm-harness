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
  options.tooling.mcp.filesystem = lib.mkOption {
    description = "The 'filesystem' MCP server.";

    default = { };

    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "filesystem";

        directories = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Directories the filesystem MCP server is permitted to access.";
        };
      };
    };
  };

  config = lib.mkIf (config.programs.claude-code.enable && config.tooling.mcp.filesystem.enable) {
    tooling.mcp.servers.filesystem = {
      command = lib.getExe pkgs.mcp-server-filesystem;
      args = config.tooling.mcp.filesystem.directories;
    };

    # Claude Code advertises MCP roots, which completely replace the server's
    # command-line directories; surface them as roots via `--add-dir' too.
    tooling.mcp.addDirs = config.tooling.mcp.filesystem.directories;

    programs.claude-code = {
      context = ''
        For filesystem operations use the `filesystem` MCP server (`mcp__filesystem__*`).
      '';

      # Read-only tools only; write tools (write_file, edit_file,
      # create_directory, move_file) stay unlisted so Claude Code prompts.
      settings.permissions.allow = map (helpers.claude-mcp-tool "filesystem") [
        "read_text_file"
        "read_media_file"
        "read_multiple_files"
        "list_directory"
        "list_directory_with_sizes"
        "directory_tree"
        "search_files"
        "get_file_info"
        "list_allowed_directories"
      ];

      settings.permissions.deny = [
        "Bash(cat:*)"
        "Bash(cd:*)"
        "Bash(ls:*)"
      ];

      settings.hooks.PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            (helpers.claude-deny-bash-hook "Bash(cat:*)" "The cat command is disallowed. Use the filesystem MCP server (read_text_file / read_multiple_files) or the Read tool instead.")
            (helpers.claude-deny-bash-hook "Bash(ls:*)" "The ls command is disallowed. Use the filesystem MCP server instead: list_directory, list_directory_with_sizes, or directory_tree.")
            (helpers.claude-deny-bash-hook "Bash(cd:*)" "The cd command is disallowed. Use absolute paths with the filesystem MCP server tools instead of changing the working directory.")
          ];
        }
      ];
    };
  };
}
