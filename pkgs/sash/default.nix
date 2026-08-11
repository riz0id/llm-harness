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
    rev = "a1c241cb3d2609d1f912529650832d950c663c48";
    hash = "sha256-koPOrfHH/YCeV60ItU/a0C697yxjtai+iGmMkR2xsTA=";
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
