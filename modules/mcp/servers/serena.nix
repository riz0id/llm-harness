{
  config,
  lib,
  pkgs,
  ...
}:

let
  helpers = import ../../../lib.nix { inherit lib; };

  serena = pkgs.callPackage ../../../pkgs/serena { };
in
{
  options.tooling.mcp.serena = lib.mkOption {
    description = "The 'serena' MCP server.";

    default = { };

    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "serena";

        context = lib.mkOption {
          type = lib.types.str;
          default = "claude-code";
          description = "Serena context to run with (built-in name or path to a custom context YAML).";
        };
      };
    };
  };

  config = lib.mkIf config.tooling.mcp.serena.enable (
    lib.mkMerge [
      {
        tooling.mcp.servers.serena = {
          command = lib.getExe serena;

          # The dashboard and GUI log window are disabled: a stdio MCP server must
          # not spawn browser windows, and the package omits the GUI dependencies.
          args = [
            "start-mcp-server"
            "--context"
            config.tooling.mcp.serena.context
            "--enable-web-dashboard"
            "false"
            "--enable-gui-log-window"
            "false"
          ];
        };

        # solidlsp downloads most language servers on demand, but nixd must
        # already be on PATH for serena to initialize Nix projects.
        home.packages = [ pkgs.nixd ];

        tooling.context = ''
          Use the `serena` MCP server (`mcp__serena__*`) for locating, editing and replacing code:
          - Locate with `find_symbol` / `get_symbols_overview`
          - Edit with `replace_symbol_body`, `insert_after_symbol` / `insert_before_symbol`, or `rename_symbol` for symbol-level changes
          - Replace with `replace_content` / `replace_in_files` for other in-file edits.

          Use the built-in Edit and Write tools for new files, non-code files, and languages serena does not support.
        '';
      }

      (lib.mkIf config.programs.claude-code.enable {
        # Symbolic read/query tools only; editing tools (replace_symbol_body,
        # insert_*_symbol, rename_symbol, replace_content, write_memory, ...)
        # stay unlisted so Claude Code prompts.
        programs.claude-code.settings.permissions.allow = map (helpers.claude-mcp-tool "serena") [
          "activate_project"
          "get_current_config"
          "initial_instructions"
          "onboarding"
          "get_symbols_overview"
          "find_symbol"
          "find_referencing_symbols"
          "find_implementations"
          "find_declaration"
          "get_diagnostics_for_file"
          "read_memory"
          "list_memories"
        ];

        # `git apply` is an editing path that bypasses both serena's symbolic
        # tools and the built-in Edit/Write tools; deny it in Bash.
        programs.claude-code.settings.permissions.deny = [ "Bash(git apply:*)" ];

        programs.claude-code.settings.hooks.PreToolUse = [
          {
            matcher = "Bash";
            hooks = [
              (helpers.claude-deny-bash-hook "Bash(git apply:*)" "Applying patches with `git apply` is disallowed. Edit code through the serena MCP server (replace_symbol_body, insert_after_symbol / insert_before_symbol, replace_content / replace_in_files) or the built-in Edit and Write tools instead.")
            ];
          }
        ];
      })

      (lib.mkIf config.programs.codex.enable {
        # "writes" auto-approves read-only tools and prompts for mutating ones,
        # approximating the per-tool allowlist Claude Code gets above.
        programs.codex.settings.mcp_servers.serena.default_tools_approval_mode = "writes";

        programs.codex.rules.llm-harness = lib.concatLines [
          (helpers.codex-prefix-rule {
            pattern = [
              "git"
              "apply"
            ];
            decision = "forbidden";
            justification = "Applying patches with `git apply` is disallowed in the shell. Edit code through the serena MCP server (replace_symbol_body, insert_after_symbol / insert_before_symbol, replace_content / replace_in_files) or the built-in file editing tools instead.";
          })
        ];

        # Serena ships a dedicated codex context; override the shared registry
        # entry (which carries the claude-code context) for Codex only. A custom
        # `tooling.mcp.serena.context' is not forwarded here.
        programs.codex.settings.mcp_servers.serena.args = lib.mkForce [
          "start-mcp-server"
          "--context"
          "codex"
          "--enable-web-dashboard"
          "false"
          "--enable-gui-log-window"
          "false"
        ];
      })
    ]
  );
}
