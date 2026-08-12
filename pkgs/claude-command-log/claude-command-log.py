#!/usr/bin/env python3

"""Record shell commands requested by coding agents in a SQLite database."""

from __future__ import annotations

import argparse
import json
import os
import shlex
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_DATABASE = Path.home() / ".claude" / "command-log.sqlite"

SCHEMA = """
CREATE TABLE IF NOT EXISTS commands (
  id INTEGER PRIMARY KEY,
  timestamp TEXT NOT NULL,
  session_id TEXT,
  cwd TEXT,
  command TEXT NOT NULL
)
"""


def database_path() -> Path:
    return Path(os.environ.get("CLAUDE_COMMAND_LOG_DB") or DEFAULT_DATABASE)


def top(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        prog="claude-command-log top",
        description="Show the most frequently requested commands.",
    )
    parser.add_argument("-n", type=int, default=10, help="number of commands to show")
    args = parser.parse_args(argv)

    database = database_path()
    if not database.exists():
        print(f"no command log at {database}", file=sys.stderr)
        return 1

    connection = sqlite3.connect(database)
    try:
        rows = connection.execute(
            "SELECT command, COUNT(*) AS uses FROM commands"
            " GROUP BY command ORDER BY uses DESC, command LIMIT ?",
            (args.n,),
        ).fetchall()
    finally:
        connection.close()

    for command, uses in rows:
        print(f"{uses}\t{command}")
    return 0


def record() -> int:
    # Never block or fail the tool call over a logging problem.
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        return 0
    if not isinstance(payload, dict):
        return 0

    tool_input = payload.get("tool_input")
    command = tool_input.get("command") if isinstance(tool_input, dict) else None
    if isinstance(command, list) and all(isinstance(part, str) for part in command):
        # Codex's shell tool passes the command as an argv list.
        command = shlex.join(command)
    if not isinstance(command, str):
        return 0

    database = database_path()
    try:
        database.parent.mkdir(parents=True, exist_ok=True)
        connection = sqlite3.connect(database)
        try:
            with connection:
                connection.execute(SCHEMA)
                connection.execute(
                    "INSERT INTO commands (timestamp, session_id, cwd, command)"
                    " VALUES (?, ?, ?, ?)",
                    (
                        datetime.now(timezone.utc).isoformat(),
                        payload.get("session_id"),
                        payload.get("cwd"),
                        command,
                    ),
                )
        finally:
            connection.close()
    except (OSError, sqlite3.Error):
        return 0

    return 0


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "record":
        return record()
    if len(sys.argv) > 1 and sys.argv[1] == "top":
        return top(sys.argv[2:])
    return top(sys.argv[1:])


if __name__ == "__main__":
    raise SystemExit(main())
