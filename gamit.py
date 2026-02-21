#!/usr/bin/env python3
import argparse
import csv
import os
import subprocess
from pathlib import Path

CURRENT_USER = os.environ.get("USER") or os.environ.get("LOGNAME") or ""
HOME_DIR = Path.home()
GAM = os.environ.get("GAM_PATH", str(HOME_DIR / "bin" / "gam7" / "gam"))
CSV_PATH = Path(
    os.environ.get(
        "CSV_PATH",
        str(HOME_DIR / "Downloads" / "exportjobopportunity-metadata.csv"),
    )
)


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
        description="Delete Gmail messages from CSV rows using RFC822 message IDs."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview operations without calling GAM delete.",
    )
    args = parser.parse_args()

    if not CSV_PATH.exists():
        print(f"[ERR] CSV file not found: {CSV_PATH}")
        return 1

    total = 0
    ran = 0
    miss = 0
    errs = 0

    with CSV_PATH.open(newline="", encoding="utf-8-sig") as file:
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

            if args.dry_run:
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
        f"(current_user={CURRENT_USER or 'unknown'} dry_run={args.dry_run})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
