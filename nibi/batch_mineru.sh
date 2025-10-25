#!/bin/bash
#SBATCH -J mineru_batch
#SBATCH -o batch_mineru_%j.out
#SBATCH -e batch_mineru_%j.err
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G
#SBATCH --gres=gpu:1
#SBATCH --time=8:00:00

# Batch process multiple PDFs with MinerU
# Conservative configuration based on OLMoCR experience

set -euo pipefail

echo "========================================="
echo "MinerU Batch Processing Job"
echo "========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "GPU: $CUDA_VISIBLE_DEVICES"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: 128G"
echo "Start time: $(date)"
echo "========================================="

# Paths
CONTAINER="${HOME}/projects/def-jic823/mineru/mineru.sif"
PDF_DIR="${HOME}/projects/def-jic823/mineru/pdfs"
OUTPUT_DIR="${HOME}/projects/def-jic823/mineru/output"
LOG_DIR="${HOME}/projects/def-jic823/mineru/logs"

# Create directories
mkdir -p "${OUTPUT_DIR}" "${LOG_DIR}"

# Validate container
if [ ! -f "${CONTAINER}" ]; then
    echo "ERROR: Container not found at ${CONTAINER}"
    exit 1
fi

if [ ! -d "${PDF_DIR}" ]; then
    echo "ERROR: PDF directory not found at ${PDF_DIR}"
    exit 1
fi

# Count PDFs
PDF_COUNT=$(find "${PDF_DIR}" -maxdepth 1 -type f -name "*.pdf" | wc -l)
echo "Found ${PDF_COUNT} PDF files to process"
echo "========================================="

if [ ${PDF_COUNT} -eq 0 ]; then
    echo "ERROR: No PDF files found in ${PDF_DIR}"
    exit 1
fi

# Process each PDF
PROCESSED=0
FAILED=0
START_TIME=$(date +%s)

while IFS= read -r pdf_path; do
    pdf_name=$(basename "${pdf_path}")
    pdf_base="${pdf_name%.pdf}"

    echo ""
    echo "Processing: ${pdf_name}"
    echo "Time: $(date)"

    PDF_START=$(date +%s)

    # Run MinerU with timeout protection
    timeout 3600 apptainer exec --nv \
        --bind "${PDF_DIR}:/input:ro" \
        --bind "${OUTPUT_DIR}:/output" \
        "${CONTAINER}" \
        mineru -p "/input/${pdf_name}" -o "/output/${pdf_base}" \
        > "${LOG_DIR}/${pdf_base}.log" 2>&1

    EXIT_CODE=$?
    PDF_END=$(date +%s)
    PDF_DURATION=$((PDF_END - PDF_START))

    if [ ${EXIT_CODE} -eq 0 ]; then
        echo "✓ SUCCESS (${PDF_DURATION}s)"
        PROCESSED=$((PROCESSED + 1))
    else
        echo "✗ FAILED (exit code: ${EXIT_CODE})"
        FAILED=$((FAILED + 1))
        # Log failure
        echo "FAILED: ${pdf_name} (exit ${EXIT_CODE})" >> "${LOG_DIR}/failures.txt"
    fi

    echo "Progress: ${PROCESSED}/${PDF_COUNT} processed, ${FAILED} failed"

done < <(find "${PDF_DIR}" -maxdepth 1 -type f -name "*.pdf" | sort)

END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

echo ""
echo "========================================="
echo "Batch Processing Complete"
echo "========================================="
echo "Total PDFs: ${PDF_COUNT}"
echo "Processed successfully: ${PROCESSED}"
echo "Failed: ${FAILED}"
echo "Total duration: ${TOTAL_DURATION} seconds"
echo "Average per PDF: $((TOTAL_DURATION / PDF_COUNT)) seconds"
echo "========================================="

if [ ${FAILED} -gt 0 ]; then
    echo "Failed files logged to: ${LOG_DIR}/failures.txt"
fi

echo "End time: $(date)"
exit 0
