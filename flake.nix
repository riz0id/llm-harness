{
  description = "Claude Code + MCP server configuration as reusable home-manager modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "aarch64-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});

      overlays.default = final: prev: import ./pkgs prev;

      homeModules = {
        claude-code = import ./modules/claude-code;

        mcp = import ./modules/mcp;

        default = import ./modules;
      };

      # Compatibility alias; some consumers look for `homeManagerModules'.
      homeManagerModules = self.homeModules;

      lib = import ./lib.nix { lib = nixpkgs.lib; };
    };
}
