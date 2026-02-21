#!/usr/bin/env python3
"""JMT 02/21/2026

Reads a CSV export of Gmail accounts and RFC822 message IDs, then deletes
matching messages via GAM. Dry run is the default; use -x to execute deletes.
"""

import argparse
import csv
import os
import subprocess
import sys
from pathlib import Path

CURRENT_USER = os.environ.get("USER") or os.environ.get("LOGNAME") or ""
HOME_DIR = Path.home()
GAM = os.environ.get("GAM_PATH", str(HOME_DIR / "bin" / "gam7" / "gam"))


def clean_msgid(value: str | None) -> str:
    if value is None:
        return ""
    value = value.replace("\r", "").strip()
    if value.startswith("<") and value.endswith(">"):
        value = value[1:-1].strip()
    return value


def clean_user(value: str | None) -> str:
    if value is None:
        return ""
    return value.replace("\r", "").strip().strip('"')


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
    if len(sys.argv) == 1:
        parser.print_help()
        return 1

    args = parser.parse_args()
    dry_run = not args.execute
    csv_path = Path(args.csv_file).expanduser()

    if not csv_path.exists():
        print(f"[ERR] CSV file not found: {csv_path}")
        return 1

    total = 0
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

            cmd = [
                GAM,
                "user",
                user,
                "delete",
                "messages",
                "query",
                f"rfc822msgid:{msgid}",
                "doit",
            ]

            if dry_run:
                ran += 1
                print(f"[DRY-RUN] user={user} msgid={msgid} cmd={' '.join(cmd)}")
                continue

            try:
                proc = subprocess.run(cmd, capture_output=True, text=True)
                ran += 1

                output = ((proc.stdout or "") + (proc.stderr or "")).strip()
                output_l = output.lower()

                if proc.returncode != 0:
                    errs += 1
                    print(f"[ERR] user={user} msgid={msgid}\\n{output}\\n---")
                elif (
                    "0 messages" in output_l
                    or "no messages" in output_l
                    or "no threads" in output_l
                ):
                    miss += 1
                    print(f"[MISS] user={user} msgid={msgid}")
                else:
                    print(f"[OK] user={user} msgid={msgid}")
            except Exception as exc:
                errs += 1
                print(f"[EXC] user={user} msgid={msgid} exc={exc}")

    print(
        f"\\nDone. rows={total} ran={ran} miss={miss} errors={errs} "
        f"(current_user={CURRENT_USER or 'unknown'} dry_run={dry_run})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
