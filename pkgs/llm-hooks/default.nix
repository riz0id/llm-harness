{
  python3,
  shfmt,
  writeShellApplication,
  ...
}:

writeShellApplication {
  name = "llm-hooks";

  runtimeInputs = [
    python3
    shfmt
  ];

  text = ''
    exec python3 ${./llm-hooks.py} "$@"
  '';
}
