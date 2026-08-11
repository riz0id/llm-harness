#!/usr/bin/env python3

"""Lifecycle hook helpers for coding agents."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from collections.abc import Callable, Sequence
from pathlib import Path
from typing import Any


PATCH_PATH_PREFIXES = (
    "*** Update File: ",
    "*** Add File: ",
    "*** Move to: ",
)


def edited_paths(patch: str) -> list[Path]:
    """Return unique, format-eligible path candidates from an apply_patch call."""
    paths: list[Path] = []
    seen: set[Path] = set()

    for line in patch.splitlines():
        for prefix in PATCH_PATH_PREFIXES:
            if line.startswith(prefix):
                path = Path(line.removeprefix(prefix))
                if path not in seen:
                    paths.append(path)
                    seen.add(path)
                break

    return paths


def formatter_command(path: Path) -> list[str] | None:
    """Select a formatter based on the edited file's name."""
    filename = path.name
    if filename.endswith((".tf", ".tfvars", ".tftest.hcl")):
        return ["terraform", "fmt", "-no-color", str(path)]
    if filename.endswith((".py", ".pyi")):
        return ["black", "--quiet", str(path)]
    if filename.endswith(".nix"):
        return ["nixfmt", str(path)]
    if filename.endswith(".sh"):
        return ["shfmt", "-w", "-i", "2", "-ci", str(path)]
    return None


def format_paths(paths: Sequence[Path]) -> list[str]:
    """Run the matching formatter over each edited path."""
    failures: list[str] = []
    for edited_path in paths:
        path = edited_path if edited_path.is_absolute() else Path.cwd() / edited_path
        if not path.is_file():
            # Deleted files and the source side of a move no longer exist.
            continue

        command = formatter_command(path)
        if command is None:
            continue

        try:
            result = subprocess.run(
                command, capture_output=True, text=True, check=False
            )
        except OSError as error:
            failures.append(f"{edited_path}: {error}")
            continue

        if result.returncode != 0:
            output = "\n".join(
                text.strip() for text in (result.stdout, result.stderr) if text.strip()
            )
            failures.append(
                f"{edited_path}: {output or f'formatter exited {result.returncode}'}"
            )

    return failures


def codex_edited_files(payload: dict[str, Any]) -> list[str]:
    """Format files named by a Codex PostToolUse apply_patch payload."""
    tool_input = payload.get("tool_input")
    if not isinstance(tool_input, dict):
        return ["Hook payload does not contain a tool_input object."]

    patch = tool_input.get("command")
    if not isinstance(patch, str):
        return ["Hook payload does not contain a string tool_input.command."]

    return format_paths(edited_paths(patch))


def claude_edited_files(payload: dict[str, Any]) -> list[str]:
    """Format the file named by a Claude Code PostToolUse edit payload."""
    tool_input = payload.get("tool_input")
    if not isinstance(tool_input, dict):
        return ["Hook payload does not contain a tool_input object."]

    edited = tool_input.get("file_path") or tool_input.get("notebook_path")
    if not isinstance(edited, str):
        return ["Hook payload does not contain a string tool_input.file_path."]

    return format_paths([Path(edited)])


def post_tool_use_feedback(failures: Sequence[str]) -> dict[str, Any]:
    reason = "Post-edit formatting failed:\n" + "\n".join(failures)
    return {
        "decision": "block",
        "reason": reason,
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": reason,
        },
    }


def post_edit(collect: Callable[[dict[str, Any]], list[str]]) -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError) as error:
        failures = [f"Could not read the hook payload: {error}"]
    else:
        failures = (
            collect(payload)
            if isinstance(payload, dict)
            else ["Hook payload must be a JSON object."]
        )

    if failures:
        json.dump(post_tool_use_feedback(failures), sys.stdout)
        sys.stdout.write("\n")

    return 0


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog="llm-hooks", description=__doc__)
    subcommands = parser.add_subparsers(dest="command", required=True)
    subcommands.add_parser(
        "codex-post-edit",
        help="Format files from a Codex PostToolUse apply_patch payload.",
    )
    subcommands.add_parser(
        "claude-post-edit",
        help="Format files from a Claude Code PostToolUse edit payload.",
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    if args.command == "codex-post-edit":
        return post_edit(codex_edited_files)
    if args.command == "claude-post-edit":
        return post_edit(claude_edited_files)
    raise AssertionError(f"Unhandled command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())
