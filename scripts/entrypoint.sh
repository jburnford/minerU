#!/usr/bin/env bash
set -euo pipefail

# Allow overriding via env
INPUT_DIR="${INPUT_PATH:-/workspace/input}"
OUTPUT_DIR="${OUTPUT_PATH:-/workspace/output}"
NUM_WORKERS="${NUM_WORKERS:-16}"
MINERU_CMD_BIN="${MINERU_CMD:-mineru}"
EXTRA_ARGS=${EXTRA_ARGS:-}

echo "[entrypoint] Using input:  ${INPUT_DIR}"
echo "[entrypoint] Using output: ${OUTPUT_DIR}"
echo "[entrypoint] Workers:      ${NUM_WORKERS}"
echo "[entrypoint] MinerU cmd:   ${MINERU_CMD_BIN}"

# Prefer GPU by default; fall back gracefully if no CUDA
export CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-0}
export OMP_NUM_THREADS=${OMP_NUM_THREADS:-${NUM_WORKERS}}
export MKL_NUM_THREADS=${MKL_NUM_THREADS:-${NUM_WORKERS}}

# Run wrapper (which calls the MinerU CLI)
python3 /usr/local/bin/run_mineru.py \
  --input "${INPUT_DIR}" \
  --output "${OUTPUT_DIR}" \
  --workers "${NUM_WORKERS}" \
  --cmd "${MINERU_CMD_BIN}" \
  ${EXTRA_ARGS}

