#!/bin/bash
#SBATCH -J mineru_bl_test
#SBATCH -o bl_test_mineru_%j.out
#SBATCH -e bl_test_mineru_%j.err
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --gres=gpu:1
#SBATCH --time=4:00:00

# Test MinerU on British Library newspaper gold standard (600 images)
# This is a benchmark test to evaluate quality on historical documents

set -euo pipefail

# Load Apptainer module
module load apptainer/1.3.5

echo "========================================="
echo "MinerU British Library Newspaper Test"
echo "========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "GPU: $CUDA_VISIBLE_DEVICES"
echo "Start time: $(date)"
echo "========================================="

# Paths
CONTAINER="${HOME}/projects/def-jic823/mineru/mineru.sif"
IMAGE_DIR="${HOME}/bl_goldstandard"  # Images in home directory
OUTPUT_DIR="${HOME}/projects/def-jic823/mineru/bl_output"
LOG_DIR="${HOME}/projects/def-jic823/mineru/bl_logs"

# Create directories
mkdir -p "${OUTPUT_DIR}" "${LOG_DIR}"

# Validate inputs
if [ ! -f "${CONTAINER}" ]; then
    echo "ERROR: Container not found at ${CONTAINER}"
    exit 1
fi

if [ ! -d "${IMAGE_DIR}" ]; then
    echo "ERROR: BL gold standard directory not found at ${IMAGE_DIR}"
    echo "Please create directory and place 600 test images there"
    exit 1
fi

# Count images (support common formats)
IMAGE_COUNT=$(find "${IMAGE_DIR}" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.tif" -o -iname "*.tiff" \) | wc -l)
echo "Found ${IMAGE_COUNT} images to process"

if [ ${IMAGE_COUNT} -eq 0 ]; then
    echo "ERROR: No images found in ${IMAGE_DIR}"
    exit 1
fi

echo "Expected: 600 images"
echo "Found: ${IMAGE_COUNT} images"
echo "========================================="

# Process each image
PROCESSED=0
FAILED=0
START_TIME=$(date +%s)

# Create a processing log with timing
TIMING_LOG="${LOG_DIR}/timing.csv"
echo "filename,duration_seconds,exit_code,filesize_bytes" > "${TIMING_LOG}"

while IFS= read -r img_path; do
    img_name=$(basename "${img_path}")
    img_base="${img_name%.*}"

    echo ""
    echo "[${PROCESSED}/${IMAGE_COUNT}] Processing: ${img_name}"

    IMG_START=$(date +%s)
    FILE_SIZE=$(stat -f%z "${img_path}" 2>/dev/null || stat -c%s "${img_path}" 2>/dev/null)

    # Run MinerU on single image
    # Note: MinerU primarily handles PDFs, but can process images
    timeout 300 apptainer exec --nv \
        --bind "${IMAGE_DIR}:/input:ro" \
        --bind "${OUTPUT_DIR}:/output" \
        "${CONTAINER}" \
        mineru -p "/input/${img_name}" -o "/output/${img_base}" \
        > "${LOG_DIR}/${img_base}.log" 2>&1

    EXIT_CODE=$?
    IMG_END=$(date +%s)
    IMG_DURATION=$((IMG_END - IMG_START))

    # Log timing data
    echo "${img_name},${IMG_DURATION},${EXIT_CODE},${FILE_SIZE}" >> "${TIMING_LOG}"

    if [ ${EXIT_CODE} -eq 0 ]; then
        echo "✓ SUCCESS (${IMG_DURATION}s)"
        PROCESSED=$((PROCESSED + 1))
    else
        echo "✗ FAILED (exit code: ${EXIT_CODE}, timeout or error)"
        FAILED=$((FAILED + 1))
        echo "FAILED: ${img_name} (exit ${EXIT_CODE})" >> "${LOG_DIR}/failures.txt"
    fi

    # Progress update every 10 images
    if [ $((PROCESSED % 10)) -eq 0 ]; then
        ELAPSED=$(($(date +%s) - START_TIME))
        AVG_TIME=$((ELAPSED / PROCESSED))
        REMAINING=$((IMAGE_COUNT - PROCESSED))
        ETA=$((AVG_TIME * REMAINING))
        echo "Progress: ${PROCESSED}/${IMAGE_COUNT} (${FAILED} failed) | ETA: $((ETA / 60))m"
    fi

done < <(find "${IMAGE_DIR}" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.tif" -o -iname "*.tiff" \) | sort)

END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

echo ""
echo "========================================="
echo "British Library Test Complete"
echo "========================================="
echo "Total images: ${IMAGE_COUNT}"
echo "Processed successfully: ${PROCESSED}"
echo "Failed: ${FAILED}"
echo "Success rate: $(awk "BEGIN {printf \"%.2f\", (${PROCESSED}/${IMAGE_COUNT})*100}")%"
echo "Total duration: ${TOTAL_DURATION} seconds ($((TOTAL_DURATION / 60)) minutes)"
echo "Average per image: $(awk "BEGIN {printf \"%.2f\", ${TOTAL_DURATION}/${IMAGE_COUNT}}")} seconds"
echo "========================================="

# Generate summary statistics
echo ""
echo "Performance Statistics:"
echo "Timing data saved to: ${TIMING_LOG}"

if [ ${FAILED} -gt 0 ]; then
    echo "Failed files logged to: ${LOG_DIR}/failures.txt"
fi

echo ""
echo "Output directory: ${OUTPUT_DIR}"
echo "Log directory: ${LOG_DIR}"
echo "End time: $(date)"

exit 0
