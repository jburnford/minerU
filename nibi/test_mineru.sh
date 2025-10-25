#!/bin/bash
#SBATCH -J mineru_test
#SBATCH -o test_mineru_%j.out
#SBATCH -e test_mineru_%j.err
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --gres=gpu:1
#SBATCH --time=1:00:00

# Test MinerU on a single PDF
# Based on successful OLMoCR configuration

set -euo pipefail

echo "========================================="
echo "MinerU Test Job"
echo "========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "GPU: $CUDA_VISIBLE_DEVICES"
echo "Start time: $(date)"
echo "========================================="

# Paths
CONTAINER="${HOME}/projects/def-jic823/mineru/mineru.sif"
PDF_DIR="${HOME}/projects/def-jic823/mineru/test_pdfs"
OUTPUT_DIR="${HOME}/projects/def-jic823/mineru/test_output"
TEST_PDF="${1:-ColonialOfficeList1896.pdf}"

# Validate inputs
if [ ! -f "${CONTAINER}" ]; then
    echo "ERROR: Container not found at ${CONTAINER}"
    echo "Please build the container first using build_container.sh"
    exit 1
fi

if [ ! -f "${PDF_DIR}/${TEST_PDF}" ]; then
    echo "ERROR: Test PDF not found at ${PDF_DIR}/${TEST_PDF}"
    echo "Please place a test PDF in ${PDF_DIR}/"
    exit 1
fi

# Create output directory
mkdir -p "${OUTPUT_DIR}"

echo "Container: ${CONTAINER}"
echo "Input PDF: ${PDF_DIR}/${TEST_PDF}"
echo "Output: ${OUTPUT_DIR}"
echo "========================================="

# Run MinerU
echo "Starting MinerU processing..."
START_TIME=$(date +%s)

apptainer exec --nv \
    --bind "${PDF_DIR}:/input:ro" \
    --bind "${OUTPUT_DIR}:/output" \
    "${CONTAINER}" \
    magic-pdf -p "/input/${TEST_PDF}" -o /output -m auto

EXIT_CODE=$?
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "========================================="
echo "Processing complete!"
echo "Exit code: ${EXIT_CODE}"
echo "Duration: ${DURATION} seconds"
echo "========================================="

# Show output
if [ ${EXIT_CODE} -eq 0 ]; then
    echo "Output files:"
    ls -lh "${OUTPUT_DIR}"

    echo ""
    echo "SUCCESS: MinerU test completed"
else
    echo "ERROR: MinerU processing failed"
fi

echo "End time: $(date)"
exit ${EXIT_CODE}
