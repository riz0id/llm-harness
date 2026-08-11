{
  fetchFromGitHub,
  lib,
  python3Packages,
}:

python3Packages.buildPythonApplication rec {
  pname = "mcp-nixos";
  version = "3.0.0";

  src = fetchFromGitHub {
    owner = "utensils";
    repo = "mcp-nixos";
    rev = "v${version}";
    hash = "sha256-ZqUFTYxXJB4RN+o+5AD8MOK1Fig+I5aOXrzpNpXL0No=";
  };

  pyproject = true;

  build-system = [ python3Packages.hatchling ];

  dependencies = with python3Packages; [
    beautifulsoup4
    fastmcp
    requests
  ];

  # The test suite queries live Elasticsearch/NixOS APIs, which is not possible
  # inside the build sandbox.
  doCheck = false;

  pythonImportsCheck = [ "mcp_nixos" ];

  meta = {
    description = "Model Context Protocol server for NixOS, Home Manager, and nix-darwin resources";
    homepage = "https://github.com/utensils/mcp-nixos";
    license = lib.licenses.mit;
    mainProgram = "mcp-nixos";
    platforms = lib.platforms.unix;
  };
}
