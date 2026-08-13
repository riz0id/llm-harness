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

  # A global core.hooksPath shadows every repo-local .git/hooks, so each hook
  # here ends by delegating to the repo-local hook of the same name.
  # `--git-path hooks` honors core.hooksPath and would resolve back to this
  # linkFarm (an infinite self-exec), so resolve via --git-dir instead.
  gitHookDelegate = name: ''
    repo_hook="$(git rev-parse --git-dir)/hooks/${name}"
    [ -x "$repo_hook" ] && exec "$repo_hook" "$@"
    exit 0
  '';

  gitHooks = pkgs.linkFarm "llm-git-hooks" (
    [
      {
        name = "commit-msg";
        path = pkgs.writeShellScript "commit-msg" ''
          ${lib.getExe llm-hooks} git-commit-msg "$1"
          ${gitHookDelegate "commit-msg"}
        '';
      }
    ]
    ++
      map
        (name: {
          inherit name;
          path = pkgs.writeShellScript name (gitHookDelegate name);
        })
        [
          "pre-commit"
          "prepare-commit-msg"
          "post-commit"
          "pre-push"
        ]
  );
in
{
  imports = [ ../common ];

  config = lib.mkMerge [
    {
      programs.claude-code = {
        enable = true;

        agents = { };

        context = config.tooling.context;

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

          # The sed rule is a sash glob extension: Claude Code's native rule
          # matching ignores it, but the sash permission hook denies matching
          # commands (quoted or not) with the advice from denyAdvice below.
          permissions.deny = [
            "Bash(sed -n [0-9]*,[0-9]*p*)"
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

          permissions.denyAdvice."Bash(sed -n [0-9]*,[0-9]*p*)" =
            "Printing a line range with `sed -n 'M,Np'` is disallowed. Use the built-in Read tool with line addressing instead: offset = M, limit = N - M + 1.";

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
                # Raw-text denials (e.g. redirect patterns) that neither
                # Claude Code's native rules nor sash stage matching can see.
                {
                  type = "command";
                  command = "${lib.getExe llm-hooks} claude-pre-bash";
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

          # Strip Claude attribution from commit messages before they land.
          # Only takes effect when the consuming config enables programs.git.
          programs.git.extraConfig.core.hooksPath = "${gitHooks}";
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
  ];
}
