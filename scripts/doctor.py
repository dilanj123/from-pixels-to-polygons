#!/usr/bin/env python3
"""Read-only Phase-0 environment report."""

from __future__ import annotations

import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run(command: list[str]) -> tuple[int, str]:
    try:
        completed = subprocess.run(
            command, cwd=ROOT, text=True, capture_output=True, check=False
        )
    except OSError as exc:
        return 127, str(exc)
    output = (completed.stdout + completed.stderr).strip()
    return completed.returncode, output


def report_tool(name: str, command: list[str], *, mandatory: bool) -> bool:
    path = shutil.which(name)
    label = "MANDATORY" if mandatory else "OPTIONAL"
    print(f"{label} {name}")
    if path is None:
        print("  path: MISSING")
        print("  status: unavailable")
        return False
    print(f"  path: {path}")
    code, output = run(command)
    print(f"  status: exit={code}")
    print(f"  version/status: {output or '<no output>'}")
    return code == 0


def main() -> int:
    print(f"project_root: {ROOT}")
    print(f"python: {sys.executable}")
    print(f"python_version: {platform.python_version()}")
    print(f"os: {platform.system()} {platform.release()}")
    print(f"machine: {platform.machine()}")
    print(f"PATH: {os.environ.get('PATH', '')}")
    print()

    core_ok = True
    core_ok &= report_tool("git", ["git", "--version"], mandatory=True)
    core_ok &= report_tool("python3", ["python3", "--version"], mandatory=True)
    core_ok &= report_tool("make", ["make", "--version"], mandatory=True)

    print()
    print("Future-phase tools (not installed automatically):")
    for name, command in (
        ("gh", ["gh", "--version"]),
        ("verilator", ["verilator", "--version"]),
        ("yosys", ["yosys", "--version"]),
        ("sby", ["sby", "--version"]),
        ("nextpnr-ecp5", ["nextpnr-ecp5", "--version"]),
    ):
        report_tool(name, command, mandatory=False)

    print()
    print("Formal solvers:")
    for name, command in (
        ("yices", ["yices", "--version"]),
        ("yices-smt2", ["yices-smt2", "--version"]),
        ("z3", ["z3", "--version"]),
        ("boolector", ["boolector", "--version"]),
        ("cvc4", ["cvc4", "--version"]),
        ("cvc5", ["cvc5", "--version"]),
    ):
        report_tool(name, command, mandatory=False)

    print()
    print("Board/programming utilities:")
    for name in ("fujprog", "openFPGALoader", "dfu-util", "ecpprog", "ujprog"):
        path = shutil.which(name)
        print(f"  {name}: {path or 'MISSING'}")

    print()
    print("GitHub CLI authentication:")
    if shutil.which("gh") is None:
        print("  status: unavailable (gh missing)")
    else:
        code, output = run(["gh", "auth", "status"])
        print(f"  status: exit={code}")
        print(f"  output: {output or '<no output>'}")

    print()
    print("Bootstrap doctor result:")
    print("  PASS: core bootstrap commands are available" if core_ok else "  FAIL: core bootstrap command missing or unusable")
    print("  Note: future-phase EDA and hardware tools are informational in GFX-000.")
    return 0 if core_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
