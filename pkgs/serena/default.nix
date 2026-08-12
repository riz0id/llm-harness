{
  fetchFromGitHub,
  lib,
  python3Packages,
}:

python3Packages.buildPythonApplication rec {
  pname = "serena";
  version = "1.7.0";

  src = fetchFromGitHub {
    owner = "oraios";
    repo = "serena";
    rev = "v${version}";
    hash = "sha256-IrsD4pnu/47M/O9b8H9c7K8WENGv3FihlqzCB6szBXg=";
  };

  pyproject = true;

  build-system = [ python3Packages.hatchling ];

  dependencies = with python3Packages; [
    anthropic
    beautifulsoup4
    cryptography
    docstring-parser
    filelock
    flask
    jinja2
    joblib
    lsprotocol
    mcp
    oslex
    overrides
    pathspec
    pillow
    psutil
    pydantic
    pygls
    python-dotenv
    python-multipart
    pyyaml
    regex
    requests
    ruamel-yaml
    sensai-utils
    starlette
    tiktoken
    tqdm
    types-pyyaml
    urllib3
    werkzeug
  ];

  # Upstream pins every dependency exactly because uvx installs from git.
  pythonRelaxDeps = true;

  # `dotenv' is a PyPI shim for python-dotenv; pywebview/pystray only back the
  # native dashboard window and tray icon, which the module disables (nixpkgs'
  # pywebview is not available on darwin).
  pythonRemoveDeps = [
    "dotenv"
    "pywebview"
    "pystray"
  ];

  # webview is imported eagerly but only used by the (disabled) native
  # dashboard window; make the import optional so the package works without
  # pywebview.
  postPatch = ''
    substituteInPlace src/serena/agent.py src/serena/util/pywebview.py \
      --replace-fail "import webview" \
    'try:
        import webview
    except ImportError:
        webview = None'
  '';

  # The test suite launches live language servers and downloads them from the
  # network, which is not possible inside the build sandbox.
  doCheck = false;

  pythonImportsCheck = [
    "serena"
    "solidlsp"
  ];

  meta = {
    description = "Coding agent toolkit providing semantic retrieval and editing capabilities through language servers";
    homepage = "https://github.com/oraios/serena";
    license = lib.licenses.mit;
    mainProgram = "serena";
    platforms = lib.platforms.unix;
  };
}
