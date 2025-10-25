# MinerU on Nibi - Quick Start

This directory contains Nibi cluster-specific deployment files for MinerU.

## Quick Deploy

### 1. On Nibi - Clone and Build

```bash
ssh nibi
cd ~/projects/def-jic823/
git clone git@github.com:jburnford/minerU.git mineru_repo

# Setup and build
mkdir -p ~/projects/def-jic823/mineru
cp mineru_repo/nibi/mineru.def ~/projects/def-jic823/mineru/
cp mineru_repo/nibi/build_container.sh ~/projects/def-jic823/mineru/
cd ~/projects/def-jic823/mineru
sbatch build_container.sh
```

### 2. Test with British Library Gold Standard (600 images)

```bash
# After container builds (~30-60 min)
cp ~/projects/def-jic823/mineru_repo/nibi/test_bl_newspapers.sh ~/projects/def-jic823/mineru/
cd ~/projects/def-jic823/mineru
sbatch test_bl_newspapers.sh
```

### 3. Monitor Results

```bash
# Watch job
squeue -u $USER
tail -f bl_test_mineru_*.out

# Check results (after job completes)
ls -lh ~/projects/def-jic823/mineru/bl_output/
cat ~/projects/def-jic823/mineru/bl_logs/timing.csv
```

## Files

- **mineru.def** - Apptainer container definition (CUDA 12 + PyTorch + MinerU)
- **build_container.sh** - Build container on Nibi (CPU job, ~30-60 min)
- **test_bl_newspapers.sh** - Test on British Library gold standard (600 images, ~2-4 hours)
- **batch_mineru.sh** - General batch processing for PDFs
- **DEPLOYMENT.md** - Complete deployment documentation

## Key Paths

- **Container**: `~/projects/def-jic823/mineru/mineru.sif`
- **BL Images**: `~/bl_goldstandard/` (600 images)
- **BL Output**: `~/projects/def-jic823/mineru/bl_output/`
- **BL Logs**: `~/projects/def-jic823/mineru/bl_logs/`

## Important Notes

- **MinerU is for printed documents** - Does NOT work well on handwriting
- **British Library test is benchmark** - Compare quality with OLMoCR
- **Conservative resources** - Based on successful OLMoCR configuration
- **H100 GPUs required** - Container built for CUDA compute capability 9.0

See **DEPLOYMENT.md** for complete documentation.
