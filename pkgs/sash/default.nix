{
  fetchFromGitHub,
  lib,
  python3Packages,
}:

python3Packages.buildPythonApplication {
  pname = "sash";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "riz0id";
    repo = "sash";
    rev = "9503914d30d02d37232e5acc886de31eb58dd5a9";
    hash = "sha256-ANxeg5GRfO07CM4JxavmGTj47LsjX06coBEcDaK0VqE=";
  };

  pyproject = true;

  build-system = [ python3Packages.hatchling ];

  nativeCheckInputs = [ python3Packages.pytestCheckHook ];

  # The Claude Code permission hook ships in tools/, outside the wheel.
  postInstall = ''
    mkdir -p $out/bin
    {
      echo "#!${python3Packages.python.interpreter}"
      cat tools/permission_hook.py
    } > $out/bin/sash-permission-hook
    chmod +x $out/bin/sash-permission-hook
  '';

  meta = {
    description = "POSIX sh reader/parser with scope-set variable binding";
    homepage = "https://github.com/riz0id/sash";
    mainProgram = "sash";
    platforms = lib.platforms.unix;
  };
}
