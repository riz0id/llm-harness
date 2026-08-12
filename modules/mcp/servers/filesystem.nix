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

  config = lib.mkIf config.tooling.mcp.filesystem.enable (
    lib.mkMerge [
      {
        tooling.mcp.servers.filesystem = {
          command = lib.getExe pkgs.mcp-server-filesystem;
          args = config.tooling.mcp.filesystem.directories;
        };

        # Claude Code advertises MCP roots, which completely replace the server's
        # command-line directories; surface them as roots via `--add-dir' too.
        # Codex has no --add-dir analogue and relies on the args above.
        tooling.mcp.addDirs = config.tooling.mcp.filesystem.directories;

        tooling.context = ''
          For filesystem operations use the `filesystem` MCP server (`mcp__filesystem__*`).
        '';
      }

      (lib.mkIf config.programs.claude-code.enable {
        programs.claude-code = {
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
      })

      (lib.mkIf config.programs.codex.enable {
        # "writes" auto-approves read-only tools and prompts for mutating ones,
        # approximating the per-tool allowlist Claude Code gets above.
        programs.codex.settings.mcp_servers.filesystem.default_tools_approval_mode = "writes";

        programs.codex.rules.llm-harness = lib.concatLines [
          (helpers.codex-prefix-rule {
            pattern = [ "cat" ];
            decision = "forbidden";
            justification = "The cat command is disallowed. Use the filesystem MCP server (read_text_file / read_multiple_files) or the built-in file tools instead.";
          })
          (helpers.codex-prefix-rule {
            pattern = [ "ls" ];
            decision = "forbidden";
            justification = "The ls command is disallowed. Use the filesystem MCP server instead: list_directory, list_directory_with_sizes, or directory_tree.";
          })
          (helpers.codex-prefix-rule {
            pattern = [ "cd" ];
            decision = "forbidden";
            justification = "The cd command is disallowed. Use absolute paths with the filesystem MCP server tools instead of changing the working directory.";
          })
        ];
      })
    ]
  );
}
