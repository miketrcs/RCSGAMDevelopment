#!/usr/bin/env python3
"""JMT 02/21/2026

Parallel GAM runner for deleting Gmail messages by RFC822 message ID from CSV.
Default preview mode is local only; use -c/--check to call GAM without delete,
or -x to execute deletes.
Developer: miketrcs
"""

import argparse
import csv
import os
import random
import subprocess
import sys
import time
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait
from dataclasses import dataclass
from pathlib import Path

CURRENT_USER = os.environ.get("USER") or os.environ.get("LOGNAME") or ""
HOME_DIR = Path.home()
GAM = os.environ.get("GAM_PATH", str(HOME_DIR / "bin" / "gam7" / "gam"))
VERSION = (
    Path(__file__).with_name("VERSION").read_text(encoding="utf-8").strip()
    if Path(__file__).with_name("VERSION").exists()
    else "0.0.0"
)
RELEASE_DATE = "2026-02-21"


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


def has_rate_limit_error(output_l: str) -> bool:
    markers = (
        "rate limit",
        "ratelimit",
        "quota",
        "429",
        "userratelimitexceeded",
        "toomanyrequests",
        "backend error",
        "temporarily unavailable",
    )
    return any(marker in output_l for marker in markers)


@dataclass(frozen=True)
class Task:
    row_num: int
    user: str
    msgid: str


@dataclass(frozen=True)
class Result:
    status: str
    user: str
    msgid: str
    output: str
    attempts: int


def build_cmd(task: Task) -> list[str]:
    cmd = [
        GAM,
        "user",
        task.user,
        "delete",
        "messages",
        "query",
        f"rfc822msgid:{task.msgid}",
    ]
    return cmd


def run_task(task: Task, mode: str, retries: int, backoff_seconds: float) -> Result:
    cmd = build_cmd(task)

    if mode == "preview":
        return Result(
            status="DRY-RUN",
            user=task.user,
            msgid=task.msgid,
            output=f"cmd={' '.join(cmd)}",
            attempts=0,
        )
    if mode == "execute":
        cmd = [*cmd, "doit"]

    attempt = 0
    while True:
        attempt += 1
        try:
            proc = subprocess.run(cmd, capture_output=True, text=True)
            output = ((proc.stdout or "") + (proc.stderr or "")).strip()
            output_l = output.lower()

            if proc.returncode == 0:
                if (
                    "0 messages" in output_l
                    or "no messages" in output_l
                    or "no threads" in output_l
                ):
                    return Result("MISS", task.user, task.msgid, output, attempt)
                if mode == "check":
                    return Result("CHECK", task.user, task.msgid, output, attempt)
                return Result("OK", task.user, task.msgid, output, attempt)

            if attempt <= retries and has_rate_limit_error(output_l):
                sleep_for = backoff_seconds * (2 ** (attempt - 1)) + random.uniform(0, 0.2)
                time.sleep(sleep_for)
                continue

            return Result("ERR", task.user, task.msgid, output, attempt)
        except Exception as exc:
            if attempt <= retries:
                sleep_for = backoff_seconds * (2 ** (attempt - 1)) + random.uniform(0, 0.2)
                time.sleep(sleep_for)
                continue
            return Result("EXC", task.user, task.msgid, str(exc), attempt)


def main() -> int:
    parser = argparse.ArgumentParser(
        add_help=False,
        formatter_class=argparse.RawTextHelpFormatter,
        description=(
            "Parallel Gmail message processing from CSV. "
            "Default is preview mode (no GAM/API call)."
        ),
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
        help="Execute delete mode (adds GAM 'doit').",
    )
    parser.add_argument(
        "-c",
        "--check",
        action="store_true",
        help="Call GAM in check mode for first 10 valid rows (no 'doit', no delete).",
    )
    parser.add_argument(
        "-w",
        "--workers",
        type=int,
        default=8,
        help="\nNumber of concurrent GAM workers (default: 8).",
    )
    parser.add_argument(
        "-r",
        "--retries",
        type=int,
        default=3,
        help="Retries for transient/rate-limit failures (default: 3).",
    )
    parser.add_argument(
        "-b",
        "--backoff",
        type=float,
        default=0.75,
        help="Base backoff seconds for retries (default: 0.75).",
    )
    parser.add_argument(
        "--version",
        action="store_true",
        help="Show script version and release date.",
    )
    if "--version" in sys.argv[1:]:
        print(f"gamgmaildeletebymsgidparallel.py v{VERSION} ({RELEASE_DATE})")
        return 0

    if len(sys.argv) == 1:
        parser.print_help()
        return 1

    args = parser.parse_args()
    if args.execute and args.check:
        print("[ERR] choose only one: -c/--check or -x/--execute")
        return 1

    if args.workers < 1:
        print("[ERR] workers must be >= 1")
        return 1
    if args.retries < 0:
        print("[ERR] retries must be >= 0")
        return 1
    if args.backoff <= 0:
        print("[ERR] backoff must be > 0")
        return 1

    mode = "preview"
    if args.check:
        mode = "check"
    elif args.execute:
        mode = "execute"
    csv_path = Path(args.csv_file).expanduser()

    if not csv_path.exists():
        print(f"[ERR] CSV file not found: {csv_path}")
        return 1

    tasks: list[Task] = []
    total_rows = 0

    with csv_path.open(newline="", encoding="utf-8-sig") as file:
        reader = csv.DictReader(file)
        for row in reader:
            total_rows += 1
            user = clean_user(row.get("Account"))
            msgid = clean_msgid(row.get("Rfc822MessageId"))
            if not user or not msgid:
                continue
            tasks.append(Task(row_num=total_rows, user=user, msgid=msgid))

    if mode == "check" and len(tasks) > 10:
        print(f"[INFO] check mode limiting to first 10 valid rows (from {len(tasks)}).")
        tasks = tasks[:10]

    ok = 0
    miss = 0
    errs = 0
    excs = 0
    ran = 0

    print(
        f"Starting. rows={total_rows} valid={len(tasks)} workers={args.workers} "
        f"retries={args.retries} mode={mode}"
    )

    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        it = iter(tasks)
        pending = set()

        for _ in range(min(args.workers, len(tasks))):
            task = next(it, None)
            if task is None:
                break
            pending.add(executor.submit(run_task, task, mode, args.retries, args.backoff))

        while pending:
            done, pending = wait(pending, return_when=FIRST_COMPLETED)
            for fut in done:
                result = fut.result()
                ran += 1

                if result.status == "OK":
                    ok += 1
                    print(f"[OK] user={result.user} msgid={result.msgid} attempts={result.attempts}")
                elif result.status == "CHECK":
                    ok += 1
                    print(
                        f"[CHECK] user={result.user} msgid={result.msgid} "
                        f"attempts={result.attempts}"
                    )
                elif result.status == "MISS":
                    miss += 1
                    print(f"[MISS] user={result.user} msgid={result.msgid} attempts={result.attempts}")
                elif result.status == "DRY-RUN":
                    print(f"[DRY-RUN] user={result.user} msgid={result.msgid} {result.output}")
                elif result.status == "ERR":
                    errs += 1
                    print(
                        f"[ERR] user={result.user} msgid={result.msgid} attempts={result.attempts}"
                        f"\n{result.output}\n---"
                    )
                else:
                    excs += 1
                    print(
                        f"[EXC] user={result.user} msgid={result.msgid} attempts={result.attempts} "
                        f"exc={result.output}"
                    )

                task = next(it, None)
                if task is not None:
                    pending.add(
                        executor.submit(run_task, task, mode, args.retries, args.backoff)
                    )

    print(
        f"\nDone. rows={total_rows} valid={len(tasks)} ran={ran} ok={ok} miss={miss} "
        f"errors={errs} exceptions={excs} "
        f"(current_user={CURRENT_USER or 'unknown'} mode={mode})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
