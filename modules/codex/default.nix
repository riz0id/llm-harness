{
  config,
  lib,
  pkgs,
  ...
}:

let
  helpers = import ../../lib.nix { inherit lib; };

  claude-command-log = pkgs.callPackage ../../pkgs/claude-command-log { };
  llm-hooks = pkgs.callPackage ../../pkgs/llm-hooks { };

  formatterPath = lib.makeBinPath [
    pkgs.black
    pkgs.nixfmt
    pkgs.terraform
  ];

  allow = pattern: helpers.codex-prefix-rule { inherit pattern; };

  deny =
    pattern: justification:
    helpers.codex-prefix-rule {
      inherit pattern justification;
      decision = "forbidden";
    };
in
{
  imports = [ ../common ];

  config = lib.mkMerge [
    {
      programs.codex = {
        enable = true;

        context = config.tooling.context;

        settings = {
          # Prompt for anything the rules below do not allow; the sandbox is
          # extra containment Claude Code gets from sash instead.
          approval_policy = "untrusted";
          sandbox_mode = "workspace-write";

          # Required for hooks.json to be honored.
          features.hooks = true;
        };

        # Codex analogue of the Claude Code permission allow/deny lists;
        # justifications carry what permissions.denyAdvice carries for Claude.
        # The `sed -n M,Np' glob deny cannot be expressed as an argv prefix
        # and is not ported.
        rules.llm-harness = lib.concatLines [
          (allow [ "rg" ])
          (allow [ "echo" ])
          (allow [
            "nix"
            "log"
          ])
          (allow [
            "nix"
            "hash"
          ])
          (deny [ "grep" ] "Use `rg` rather than `grep`.")
          (deny [ "head" ] "Do not use the `head` command. Read files with the built-in file tools instead.")
          (deny [ "tail" ] "Do not use the `tail` command. Read files with the built-in file tools instead.")
          (deny [ "sudo" ] "Never run commands with sudo.")
          (deny [
            "terraform"
            "fmt"
          ] "Do not format code.")
          (deny [ "black" ] "Do not format code.")
          (deny [ "ormolu" ] "Do not format code.")
          (deny [ "shfmt" ] "Do not format code.")
          (deny [ "nixfmt" ] "Do not format code.")
          (deny [
            "ruff"
            "check"
          ] "Do not lint code.")
          (deny [
            "ruff"
            "format"
          ] "Do not format code.")
        ];

        hooks = {
          PreToolUse = [
            {
              matcher = "shell|local_shell";
              hooks = [
                # Record every requested shell command verbatim in the same
                # database Claude Code logs to (~/.claude/command-log.sqlite).
                {
                  type = "command";
                  command = "${lib.getExe claude-command-log} record";
                  timeout = 10;
                  async = true;
                }
              ];
            }
          ];

          PostToolUse = [
            {
              matcher = "apply_patch";
              hooks = [
                {
                  type = "command";
                  command = "${lib.getExe' pkgs.coreutils "env"} PATH=${formatterPath} ${lib.getExe llm-hooks} codex-post-edit";
                  timeout = 30;
                }
              ];
            }
          ];
        };
      };
    }

    (lib.mkIf config.programs.codex.enable {
      home.packages = [
        claude-command-log
        llm-hooks
      ];
    })
  ];
}
