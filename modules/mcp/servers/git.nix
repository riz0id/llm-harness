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
  options.tooling.mcp.git = lib.mkOption {
    description = "The 'git' MCP server.";

    default = { };

    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "git";
      };
    };
  };

  config = lib.mkIf config.tooling.mcp.git.enable (
    lib.mkMerge [
      {
        tooling.mcp.servers.git.command = lib.getExe pkgs.mcp-server-git;

        tooling.context = ''
          For `git` use the `git` MCP server (`mcp__git__*`).
        '';
      }

      (lib.mkIf config.programs.claude-code.enable {
        programs.claude-code = {
          # Read-only tools only; write tools (git_add, git_commit, git_reset,
          # git_checkout, git_create_branch) stay unlisted so Claude Code prompts.
          settings.permissions.allow = map (helpers.claude-mcp-tool "git") [
            "git_status"
            "git_diff"
            "git_diff_staged"
            "git_diff_unstaged"
            "git_log"
            "git_show"
            "git_branch"
          ];

          # Redirect git subcommands this server covers to its tools. Subcommands
          # it cannot perform (push, pull, fetch, merge, rebase, stash, ...) stay
          # available through Bash.
          settings.hooks.PreToolUse = [
            {
              matcher = "Bash";
              hooks =
                map
                  (
                    rule:
                    helpers.claude-deny-bash-hook rule "This git subcommand is disallowed in Bash. Use the git MCP server instead: git_status, git_diff / git_diff_staged / git_diff_unstaged, git_log, git_show, git_branch, git_add, git_commit, git_checkout, git_create_branch, git_reset. Git subcommands the server does not cover (push, pull, fetch, merge, rebase, stash, ...) may still be run via Bash."
                  )
                  [
                    "Bash(git status:*)"
                    "Bash(git diff:*)"
                    "Bash(git log:*)"
                    "Bash(git show:*)"
                    "Bash(git branch:*)"
                    "Bash(git add:*)"
                    "Bash(git commit:*)"
                    "Bash(git checkout:*)"
                    "Bash(git switch:*)"
                    "Bash(git reset:*)"
                  ];
            }
          ];
        };
      })

      (lib.mkIf config.programs.codex.enable {
        # "writes" auto-approves read-only tools and prompts for mutating ones,
        # approximating the per-tool allowlist Claude Code gets above.
        programs.codex.settings.mcp_servers.git.default_tools_approval_mode = "writes";

        programs.codex.rules.llm-harness = lib.concatLines (
          map
            (
              subcommand:
              helpers.codex-prefix-rule {
                pattern = [
                  "git"
                  subcommand
                ];
                decision = "forbidden";
                justification = "This git subcommand is disallowed in the shell. Use the git MCP server instead: git_status, git_diff / git_diff_staged / git_diff_unstaged, git_log, git_show, git_branch, git_add, git_commit, git_checkout, git_create_branch, git_reset. Git subcommands the server does not cover (push, pull, fetch, merge, rebase, stash, ...) may still be run in the shell.";
              }
            )
            [
              "status"
              "diff"
              "log"
              "show"
              "branch"
              "add"
              "commit"
              "checkout"
              "switch"
              "reset"
            ]
        );
      })
    ]
  );
}
