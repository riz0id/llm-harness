{
  lib,
  buildGoModule,
  fetchFromGitHub,
  fetchurl,
  stdenv,
}:

let
  # Must match `mcpServerVersion' in mcp_version.go of the tagged source; the
  # archive checksum is verified at runtime against an in-source SHA256.
  mcpServerVersion = "1.7.0";

  bundles = {
    aarch64-darwin = {
      name = "github-mcp-server_Darwin_arm64.tar.gz";
      hash = "sha256-2+Isc7PrlJHMPifbpFNSuYCxxD5MhXZFaJoCUcXgaiE=";
    };
    x86_64-darwin = {
      name = "github-mcp-server_Darwin_x86_64.tar.gz";
      hash = "sha256-2U0BhkGhfpGTFIY0yRcBdg6/eWPvwLALKmWr597TLS4=";
    };
    aarch64-linux = {
      name = "github-mcp-server_Linux_arm64.tar.gz";
      hash = "sha256-UL1rTmBNEDlXdxBDHHAlqbHAW4rM5FgAG7U/eS541D8=";
    };
    x86_64-linux = {
      name = "github-mcp-server_Linux_x86_64.tar.gz";
      hash = "sha256-tlOioB8z6acmtYH6DYqNmgWoavQZ5aszuOJoWDZtHWY=";
    };
  };

  bundle = bundles.${stdenv.hostPlatform.system};

  bundleArchive = fetchurl {
    url = "https://github.com/github/github-mcp-server/releases/download/v${mcpServerVersion}/${bundle.name}";
    hash = bundle.hash;
  };
in

buildGoModule rec {
  pname = "gh-mcp";
  version = "3.7.0";

  src = fetchFromGitHub {
    owner = "shuymn";
    repo = "gh-mcp";
    rev = "v${version}";
    hash = "sha256-JjFUK5dGW7F8L79ifzxJXrqPsfklOIJ/62ouVvlFWxU=";
  };

  vendorHash = "sha256-9GzeKtsoVXvZma77lGKkKgyElySyDDGturwGV+HIL2g=";

  subPackages = [ "." ];

  preBuild = ''
    cp ${bundleArchive} bundled/${bundle.name}
  '';

  doCheck = false;

  meta = {
    description = "GitHub CLI extension that runs github-mcp-server using gh authentication";
    homepage = "https://github.com/shuymn/gh-mcp";
    license = lib.licenses.mit;
    mainProgram = "gh-mcp";
  };
}
