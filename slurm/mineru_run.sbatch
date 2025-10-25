#!/bin/bash
#SBATCH -J mineru
#SBATCH -o logs/mineru_%j.out
#SBATCH -e logs/mineru_%j.err
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --cpus-per-task=32
#SBATCH --mem=200G
#SBATCH --gres=gpu:h100:1
#SBATCH --time=24:00:00

# Adjust as needed:
PARTITION=${PARTITION:-gpu}
ACCOUNT=${ACCOUNT:-$SLURM_ACCOUNT}
QOS=${QOS:-normal}
CONSTRAINT=${CONSTRAINT:-h100}

# If your cluster requires explicit partition/account:
#SBATCH -p ${PARTITION}
#SBATCH -A ${ACCOUNT}
#SBATCH --qos=${QOS}
#SBATCH --constraint=${CONSTRAINT}

set -euo pipefail
mkdir -p logs

# -------------------------------------------------------------
# Configuration
# -------------------------------------------------------------
# Container image (must be accessible from compute nodes)
IMAGE_URI=${IMAGE_URI:-"ghcr.io/your-org/mineru-nibi:latest"}

# IO paths (shared file system)
INPUT_PATH=${INPUT_PATH:-"$PWD/input"}
OUTPUT_PATH=${OUTPUT_PATH:-"$PWD/output"}
NUM_WORKERS=${NUM_WORKERS:-32}

echo "SLURM job: $SLURM_JOB_ID on $(hostname)"
echo "Image:     $IMAGE_URI"
echo "Input:     $INPUT_PATH"
echo "Output:    $OUTPUT_PATH"

mkdir -p "$OUTPUT_PATH"

# -------------------------------------------------------------
# Option A: Apptainer/Singularity (preferred on HPC)
# -------------------------------------------------------------
if command -v apptainer >/dev/null 2>&1; then
  echo "[slurm] Running via Apptainer"
  srun apptainer exec --nv \
    --bind "${INPUT_PATH}:/workspace/input:ro" \
    --bind "${OUTPUT_PATH}:/workspace/output" \
    docker://${IMAGE_URI} \
    /usr/local/bin/entrypoint.sh
  exit $?
fi

# -------------------------------------------------------------
# Option B: Docker (if permitted on compute nodes)
# -------------------------------------------------------------
if command -v docker >/dev/null 2>&1; then
  echo "[slurm] Running via Docker"
  srun docker run --rm --gpus all \
    -e INPUT_PATH=/workspace/input \
    -e OUTPUT_PATH=/workspace/output \
    -e NUM_WORKERS=${NUM_WORKERS} \
    -v "${INPUT_PATH}:/workspace/input:ro" \
    -v "${OUTPUT_PATH}:/workspace/output" \
    ${IMAGE_URI}
  exit $?
fi

echo "No supported container runtime found (apptainer or docker)."
exit 1

