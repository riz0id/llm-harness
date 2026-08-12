{
  config,
  lib,
  pkgs,
  ...
}:

let
  helpers = import ../../../lib.nix { inherit lib; };

  mcp-nixos = pkgs.callPackage ../../../pkgs/mcp-nixos { };
in
{
  options.tooling.mcp.nixos = lib.mkOption {
    description = "The 'nixos' MCP server.";

    default = { };

    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "nixos";
      };
    };
  };

  config = lib.mkIf config.tooling.mcp.nixos.enable (
    lib.mkMerge [
      {
        tooling.mcp.servers.nixos.command = lib.getExe mcp-nixos;

        tooling.context = ''
          For `nix` queries use the `nixos` MCP server (`mcp__nixos__*`).
        '';
      }

      (lib.mkIf config.programs.claude-code.enable {
        programs.claude-code = {
          # Both tools are read-only queries against the NixOS/Home Manager/darwin
          # option and package indices.
          settings.permissions.allow = map (helpers.claude-mcp-tool "nixos") [
            "nix"
            "nix_versions"
          ];

          # Redirect nix CLI query commands to this server. Local operations the
          # server cannot perform (nix build, nix flake, nix log, ...) stay
          # available through Bash.
          settings.hooks.PreToolUse = [
            {
              matcher = "Bash";
              hooks =
                map
                  (
                    rule:
                    helpers.claude-deny-bash-hook rule "Querying packages, options, or channels with the nix CLI is disallowed. Use the nixos MCP server instead: the nix tool (actions: search, info, channels, cache, store, flake-inputs) or nix_versions for version history."
                  )
                  [
                    "Bash(nix search:*)"
                    "Bash(nix-env:*)"
                    "Bash(nix-channel:*)"
                  ];
            }
          ];
        };
      })

      (lib.mkIf config.programs.codex.enable {
        programs.codex.settings.mcp_servers.nixos.default_tools_approval_mode = "auto";

        programs.codex.rules.llm-harness = lib.concatLines (
          map
            (
              pattern:
              helpers.codex-prefix-rule {
                inherit pattern;
                decision = "forbidden";
                justification = "Querying packages, options, or channels with the nix CLI is disallowed. Use the nixos MCP server instead: the nix tool (actions: search, info, channels, cache, store, flake-inputs) or nix_versions for version history.";
              }
            )
            [
              [
                "nix"
                "search"
              ]
              [ "nix-env" ]
              [ "nix-channel" ]
            ]
        );
      })
    ]
  );
}
