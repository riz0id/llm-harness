# Helper functions shared by the llm-harness modules. Imported locally
# (`import ../lib.nix { inherit lib; }') rather than injected via a lib
# overlay so consumers need no lib extension.

{ lib }:

{
  # Produces a Claude Code PreToolUse hook entry denying Bash commands
  # that match the given permission rule, surfacing `reason' so Claude
  # is redirected to the preferred alternative (typically an MCP tool).
  claude-deny-bash-hook = rule: reason: {
    type = "command";
    "if" = rule;
    command = "echo ${
      lib.escapeShellArg (
        builtins.toJSON {
          hookSpecificOutput = {
            hookEventName = "PreToolUse";
            permissionDecision = "deny";
            permissionDecisionReason = reason;
          };
        }
      )
    }";
    timeout = 5;
  };

  # Produces the permission rule name for a tool of an MCP server passed
  # to Claude Code via `--mcp-config'.
  claude-mcp-tool = server: tool: "mcp__${server}__${tool}";

  # Renders a Starlark `prefix_rule' entry for a Codex rules file
  # (CODEX_HOME/rules/*.rules). JSON string/list literals are valid Starlark,
  # so builtins.toJSON handles all quoting.
  codex-prefix-rule =
    {
      pattern,
      decision ? "allow",
      justification ? null,
    }:
    "prefix_rule(pattern = ${builtins.toJSON pattern}, decision = ${builtins.toJSON decision}"
    + lib.optionalString (justification != null) ", justification = ${builtins.toJSON justification}"
    + ")";
}
