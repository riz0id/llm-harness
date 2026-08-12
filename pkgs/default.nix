# Packages used by the llm-harness home-manager modules. Exposed flat (no
# nested namespace) so both the flake `packages' output and the overlay can
# evaluate every leaf.

# This variable `pkgs' must be a plain argument (i.e. not a `{ ... }' form).
# Otherwise an infinite recursion will occur when used as an overlay.
pkgs:

{
  claude-command-log = pkgs.callPackage ./claude-command-log { };

  gh-mcp = pkgs.callPackage ./gh-mcp { };

  llm-hooks = pkgs.callPackage ./llm-hooks { };

  mcp-nixos = pkgs.callPackage ./mcp-nixos { };

  sash = pkgs.callPackage ./sash { };

  serena = pkgs.callPackage ./serena { };
}
