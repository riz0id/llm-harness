{
  python3,
  writeShellApplication,
  ...
}:

writeShellApplication {
  name = "claude-command-log";

  runtimeInputs = [
    python3
  ];

  text = ''
    exec python3 ${./claude-command-log.py} "$@"
  '';
}
