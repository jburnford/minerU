#!/usr/bin/env python3
import argparse
import os
import shlex
import subprocess
import sys
from pathlib import Path


def which(cmd: str) -> str | None:
    for p in os.environ.get("PATH", "").split(os.pathsep):
        candidate = Path(p) / cmd
        if candidate.exists() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def main():
    parser = argparse.ArgumentParser(description="Run MinerU over an input path to an output path")
    parser.add_argument("--input", required=True, help="Input file or directory (PDFs/images)")
    parser.add_argument("--output", required=True, help="Output directory for results")
    parser.add_argument("--workers", default=os.environ.get("NUM_WORKERS", "16"), help="Worker threads for I/O/preprocessing")
    parser.add_argument("--cmd", default=os.environ.get("MINERU_CMD", "mineru"), help="MinerU CLI command (override with MINERU_CMD)")
    parser.add_argument("--config", default=os.environ.get("MINERU_CONFIG", ""), help="Optional MinerU YAML config")
    parser.add_argument("--extra", default=os.environ.get("MINERU_EXTRA", ""), help="Additional raw args to append")
    args, unknown = parser.parse_known_args()

    input_path = Path(args.input)
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Resolve CLI
    mineru_cmd = args.cmd
    if which(mineru_cmd) is None:
        # try python -m mineru fallback
        mineru_cmd = f"{sys.executable} -m mineru"

    cmd = [
        *shlex.split(mineru_cmd),
        "--input", str(input_path),
        "--output", str(output_dir),
        "--workers", str(args.workers),
    ]

    if args.config:
        cmd += ["--config", args.config]

    if args.extra:
        cmd += shlex.split(args.extra)

    if unknown:
        cmd += unknown

    print("[run] Executing:", " ".join(shlex.quote(c) for c in cmd), flush=True)
    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as e:
        print(f"[run] MinerU exited with {e.returncode}", file=sys.stderr)
        sys.exit(e.returncode)


if __name__ == "__main__":
    main()

