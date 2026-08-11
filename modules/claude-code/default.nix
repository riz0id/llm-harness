{
  config,
  lib,
  pkgs,
  ...
}:

let
  claude-command-log = pkgs.callPackage ../../pkgs/claude-command-log { };
  llm-hooks = pkgs.callPackage ../../pkgs/llm-hooks { };
  sash = pkgs.callPackage ../../pkgs/sash { };

  formatterPath = lib.makeBinPath [
    pkgs.black
    pkgs.nixfmt
    pkgs.terraform
  ];
in
lib.mkMerge [
  {
    programs.claude-code = {
      enable = true;

      agents = { };

      context = builtins.readFile ./context.md;

      settings = {
        model = "claude-fable-5";

        autoMemoryEnabled = false;

        # Keep claude.ai remote connectors (Gmail, Google Drive, Google
        # Calendar) out of CLI sessions.
        disableClaudeAiConnectors = true;

        permissions.allow = [
          "Bash(rg:*)"
          "Bash(echo:*)"
          "Bash(nix log:*)"
          "Bash(nix hash:*)"
          "Read"
        ];

        permissions.deny = [
          "Bash(grep:*)"
          "Bash(head:*)"
          "Bash(tail:*)"
          "Bash(terraform fmt:*)"
          "Bash(black:*)"
          "Bash(ormolu:*)"
          "Bash(shfmt:*)"
          "Bash(nixfmt:*)"
          "Bash(ruff check :*)"
          "Bash(ruff format :*)"
          "Bash(sudo:*)"
        ];

        # Auto-allow Bash commands that sash proves are literal-only and
        # covered by an existing Bash(...) allow rule; everything else falls
        # through to the normal permission prompt.
        hooks.PreToolUse = [
          {
            matcher = "Bash";
            hooks = [
              # Record every requested Bash command verbatim in
              # ~/.claude/command-log.sqlite.
              {
                type = "command";
                command = "${lib.getExe claude-command-log} record";
                timeout = 10;
                async = true;
              }
              {
                type = "command";
                command = lib.getExe' sash "sash-permission-hook";
                timeout = 10;
              }
            ];
          }
        ];

        hooks.PostToolUse = [
          {
            matcher = "Edit|MultiEdit|Write|NotebookEdit";
            hooks = [
              {
                type = "command";
                command = "${lib.getExe' pkgs.coreutils "env"} PATH=${formatterPath} ${lib.getExe llm-hooks} claude-post-edit";
                timeout = 30;
              }
            ];
          }
        ];
      };
    };
  }
  (lib.mkIf config.programs.claude-code.enable (
    lib.mkMerge [
      {
        home.packages = [
          claude-command-log
          llm-hooks
          sash
        ];
      }
      (lib.mkIf config.programs.vscode.enable {
        # nodejs is required by the claude-code vscode extension.
        home.packages = [ pkgs.nodejs ];

        programs.vscode.profiles.default.extensions = [
          pkgs.vscode-extensions.anthropic.claude-code
        ];
      })
    ]
  ))
]
