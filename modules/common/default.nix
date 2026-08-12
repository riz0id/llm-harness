# Options shared by every agent module. Imported by the claude-code, codex,
# and mcp modules; the module system deduplicates the import by path, so any
# combination of agent modules may be imported together.

{ lib, ... }:

{
  options.tooling.context = lib.mkOption {
    description = "Agent-agnostic instruction text surfaced to every enabled agent (Claude Code's CLAUDE.md, Codex's AGENTS.md).";
    type = lib.types.lines;
    default = "";
  };

  config.tooling.context = ''
    Do not format code.
    Do not lint code.
    Do not include testing/verification in plans.
    Use `rg` rather than `grep`.
    Do not use the `head` command.
    Do not use the `tail` command.
    End the response when the answer is complete.
  '';
}
