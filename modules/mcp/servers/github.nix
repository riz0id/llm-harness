{
  config,
  lib,
  pkgs,
  ...
}:

let
  helpers = import ../../../lib.nix { inherit lib; };

  gh-mcp = pkgs.callPackage ../../../pkgs/gh-mcp { };
in
{
  options.tooling.mcp.github = lib.mkOption {
    description = "The 'github' MCP server.";

    default = { };

    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "github";
      };
    };
  };

  config = lib.mkIf config.tooling.mcp.github.enable (
    lib.mkMerge [
      {
        tooling.mcp.servers.github.command = lib.getExe gh-mcp;

        # gh-mcp resolves credentials through the gh CLI.
        home.packages = [
          pkgs.gh
          gh-mcp
        ];

        tooling.context = ''
          For `gh` / GitHub operations use the `github` MCP server (`mcp__github__*`).
        '';
      }

      (lib.mkIf config.programs.claude-code.enable {
        programs.claude-code.settings.hooks.PreToolUse = [
          {
            matcher = "Bash";
            hooks = [
              (helpers.claude-deny-bash-hook "Bash(gh:*)" "The 'gh' command is disallowed in Bash. Use the github MCP server tools (mcp__github__*) for GitHub operations (PRs, issues, workflows, releases, ...).")
            ];
          }
        ];
      })

      (lib.mkIf config.programs.codex.enable {
        # "writes" auto-approves read-only tools and prompts for mutating ones.
        programs.codex.settings.mcp_servers.github.default_tools_approval_mode = "writes";

        programs.codex.rules.llm-harness = lib.concatLines [
          (helpers.codex-prefix-rule {
            pattern = [ "gh" ];
            decision = "forbidden";
            justification = "The 'gh' command is disallowed in the shell. Use the github MCP server tools for GitHub operations (PRs, issues, workflows, releases, ...).";
          })
        ];
      })
    ]
  );
}
