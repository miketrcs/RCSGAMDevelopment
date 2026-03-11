#!/usr/bin/env python3
"""JMT 02/21/2026

Reads a CSV export of Gmail accounts and RFC822 message IDs, then deletes
matching messages via GAM. Preview is the default; use -c to check first 10
valid rows without delete, or -x to execute deletes.
Developer: miketrcs
"""

import argparse
import csv
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Optional

CURRENT_USER = os.environ.get("USER") or os.environ.get("LOGNAME") or ""
HOME_DIR = Path.home()
GAM = os.environ.get("GAM_PATH", str(HOME_DIR / "bin" / "gam7" / "gam"))
VERSION = (
    Path(__file__).with_name("VERSION").read_text(encoding="utf-8").strip()
    if Path(__file__).with_name("VERSION").exists()
    else "0.0.0"
)
RELEASE_DATE = "2026-02-21"
ANSI_RESET = "\033[0m"
ANSI_BOLD = "\033[1m"
ANSI_GREEN = "\033[32m"
ANSI_CYAN = "\033[36m"
ANSI_YELLOW = "\033[33m"


def clean_msgid(value: Optional[str]) -> str:
    if value is None:
        return ""
    value = value.replace("\r", "").strip()
    if value.startswith("<") and value.endswith(">"):
        value = value[1:-1].strip()
    return value


def clean_user(value: Optional[str]) -> str:
    if value is None:
        return ""
    return value.replace("\r", "").strip().strip('"')


def should_use_color(stream) -> bool:
    if os.environ.get("NO_COLOR"):
        return False
    if os.environ.get("FORCE_COLOR") or os.environ.get("CLICOLOR_FORCE"):
        return True
    return hasattr(stream, "isatty") and stream.isatty()


def colorize_help(text: str) -> str:
    lines = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("usage:"):
            line = line.replace(
                "usage:",
                f"{ANSI_BOLD}{ANSI_GREEN}usage:{ANSI_RESET}",
                1,
            )
        elif stripped.endswith(":") and not line.startswith(" "):
            line = f"{ANSI_BOLD}{ANSI_YELLOW}{line}{ANSI_RESET}"
        else:
            line = re.sub(
                r"^(\s*)(-[\w],\s+--[\w-]+|--[\w-]+)",
                rf"\1{ANSI_CYAN}\2{ANSI_RESET}",
                line,
            )
        lines.append(line)
    return "\n".join(lines)


def print_help(parser: argparse.ArgumentParser) -> None:
    text = parser.format_help()
    if should_use_color(sys.stdout):
        text = colorize_help(text)
    print(text, end="")


def is_no_match_output(output_l: str) -> bool:
    markers = (
        "0 messages",
        "got 0 messages",
        "no messages",
        "no threads",
        "no messages matched",
        "not deleted: no messages matched",
    )
    return any(marker in output_l for marker in markers)


def main() -> int:
    parser = argparse.ArgumentParser(
        add_help=False,
        description="Delete Gmail messages from CSV rows using RFC822 message IDs."
    )
    parser.add_argument(
        "-f",
        "--csv-file",
        required=True,
        help="Path to the CSV file containing Account and Rfc822MessageId columns.",
    )
    parser.add_argument(
        "-x",
        "--execute",
        action="store_true",
        help="Disable dry run and delete matching emails.",
    )
    parser.add_argument(
        "-c",
        "--check",
        action="store_true",
        help="Call GAM in check mode for first 10 valid rows (no 'doit', no delete).",
    )
    parser.add_argument(
        "--version",
        action="store_true",
        help="Show script version and release date.",
    )
    parser.add_argument(
        "-h",
        "--help",
        action="store_true",
        help="Show this help message and exit.",
    )
    if "--version" in sys.argv[1:]:
        print(f"gamgmaildeletebymsgid.py v{VERSION} ({RELEASE_DATE})")
        return 0
    if "-h" in sys.argv[1:] or "--help" in sys.argv[1:]:
        print_help(parser)
        return 0
    if len(sys.argv) == 1:
        print_help(parser)
        return 1

    args = parser.parse_args()
    if args.execute and args.check:
        print("[ERR] choose only one: -c/--check or -x/--execute")
        return 1

    mode = "preview"
    if args.check:
        mode = "check"
    elif args.execute:
        mode = "execute"

    dry_run = mode == "preview"
    csv_path = Path(args.csv_file).expanduser()

    if not csv_path.exists():
        print(f"[ERR] CSV file not found: {csv_path}")
        return 1

    total = 0
    valid = 0
    ran = 0
    miss = 0
    errs = 0

    with csv_path.open(newline="", encoding="utf-8-sig") as file:
        reader = csv.DictReader(file)
        for row in reader:
            total += 1
            user = clean_user(row.get("Account"))
            msgid = clean_msgid(row.get("Rfc822MessageId"))

            if not user or not msgid:
                continue

            valid += 1
            if mode == "check" and valid > 10:
                continue

            cmd = [
                GAM,
                "user",
                user,
                "delete",
                "messages",
                "query",
                f"rfc822msgid:{msgid}",
            ]

            if dry_run:
                ran += 1
                print(f"[CSV-TEST] user={user} msgid={msgid} cmd={' '.join(cmd)}")
                continue

            if mode == "execute":
                cmd.append("doit")

            try:
                proc = subprocess.run(cmd, capture_output=True, text=True)
                ran += 1

                output = ((proc.stdout or "") + (proc.stderr or "")).strip()
                output_l = output.lower()

                if is_no_match_output(output_l):
                    miss += 1
                    if mode == "check":
                        print(f"[DRYRUNNOMATCH] user={user} msgid={msgid}")
                    else:
                        print(f"[NOMATCH] user={user} msgid={msgid}")
                elif proc.returncode != 0:
                    errs += 1
                    print(f"[ERR] user={user} msgid={msgid}\\n{output}\\n---")
                elif mode == "check":
                    print(f"[DRYRUNFOUND] user={user} msgid={msgid}")
                else:
                    print(f"[DELETED] user={user} msgid={msgid}")
            except Exception as exc:
                errs += 1
                print(f"[EXC] user={user} msgid={msgid} exc={exc}")

    print(
        f"\\nDone. rows={total} ran={ran} miss={miss} errors={errs} "
        f"(current_user={CURRENT_USER or 'unknown'} mode={mode})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
