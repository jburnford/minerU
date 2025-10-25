#!/bin/bash
#SBATCH -J mineru_build
#SBATCH -o build_mineru_%j.out
#SBATCH -e build_mineru_%j.err
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=2:00:00

# Build MinerU Apptainer container on Nibi cluster
# This is a CPU-only build job (no GPU needed)

set -euo pipefail

# Load Apptainer module
module load apptainer/1.3.5

echo "Building MinerU Apptainer container..."
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "Apptainer version: $(apptainer --version)"
echo "Start time: $(date)"

# Ensure output directory exists
BUILD_DIR="${HOME}/projects/def-jic823/mineru"
mkdir -p "${BUILD_DIR}"

# Build container
cd "${BUILD_DIR}"
apptainer build --force mineru.sif mineru.def

if [ $? -eq 0 ]; then
    echo "Container built successfully: ${BUILD_DIR}/mineru.sif"
    ls -lh "${BUILD_DIR}/mineru.sif"
else
    echo "Container build failed!"
    exit 1
fi

echo "End time: $(date)"
