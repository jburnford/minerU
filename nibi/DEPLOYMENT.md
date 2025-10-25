# MinerU Deployment on Nibi Cluster

## Overview
MinerU is an advanced PDF/document processing tool optimized for extracting text, tables, and layout from complex documents. This deployment is configured for Nibi's H100 GPUs.

**Official Repository**: https://github.com/opendatalab/MinerU
**Documentation**: https://mineru.net/

**Primary Use Case**: British Library newspaper collection (600 image gold standard) and other historical published documents.

**Note**: MinerU is optimized for printed/published documents. It does NOT work well on handwriting.

## Installation Method

This deployment uses the **official OpenDataLab MinerU** package:
- **Package**: `mineru[core]` (installed via `uv pip install`)
- **Command**: `mineru` (NOT `magic-pdf` - that's an outdated fork)

## Prerequisites

### On Nibi Cluster
1. Access to H100 GPU nodes
2. Apptainer/Singularity installed
3. Project directory: `~/projects/def-jic823/mineru/`

### Test Data Location
- **British Library Gold Standard**: `~/bl_goldstandard/` (600 images)
- Images should be in common formats: JPG, PNG, TIFF

## Deployment Steps

### 1. Clone Repository on Nibi

```bash
ssh nibi
cd ~/projects/def-jic823/
git clone git@github.com:jburnford/minerU.git mineru_repo
cd mineru_repo
```

### 2. Build Apptainer Container

```bash
# Copy definition file to build location
mkdir -p ~/projects/def-jic823/mineru
cp nibi/mineru.def ~/projects/def-jic823/mineru/

# Submit build job
cd ~/projects/def-jic823/mineru
cp ~/projects/def-jic823/mineru_repo/nibi/build_container.sh .
sbatch build_container.sh
```

**Build time**: ~30-60 minutes (CPU-only job)
**Output**: `~/projects/def-jic823/mineru/mineru.sif` (~8-10GB)

Monitor build: `tail -f build_mineru_*.out`

### 3. Test with British Library Gold Standard

Once container is built:

```bash
# Copy test script
cp ~/projects/def-jic823/mineru_repo/nibi/test_bl_newspapers.sh ~/projects/def-jic823/mineru/
cd ~/projects/def-jic823/mineru

# Submit test job
sbatch test_bl_newspapers.sh
```

**Expected Results**:
- Processing time: ~2-4 hours for 600 images
- Average: 12-24 seconds per image (estimated)
- Success rate: TBD (benchmark test)

**Output Locations**:
- Processed results: `~/projects/def-jic823/mineru/bl_output/`
- Logs: `~/projects/def-jic823/mineru/bl_logs/`
- Timing data: `~/projects/def-jic823/mineru/bl_logs/timing.csv`
- Failures: `~/projects/def-jic823/mineru/bl_logs/failures.txt`

### 4. Batch Processing (General Use)

For processing multiple PDFs:

```bash
# Place PDFs in: ~/projects/def-jic823/mineru/pdfs/
# Copy batch script
cp ~/projects/def-jic823/mineru_repo/nibi/batch_mineru.sh ~/projects/def-jic823/mineru/

# Submit batch job
sbatch batch_mineru.sh
```

## Resource Configuration

### Test Job (test_bl_newspapers.sh)
- **CPUs**: 16
- **Memory**: 64GB
- **GPU**: 1x H100
- **Walltime**: 4 hours
- **Use case**: British Library gold standard (600 images)

### Batch Job (batch_mineru.sh)
- **CPUs**: 16
- **Memory**: 128GB
- **GPU**: 1x H100
- **Walltime**: 8 hours
- **Use case**: Large PDF collections

### Build Job (build_container.sh)
- **CPUs**: 8
- **Memory**: 32GB
- **GPU**: None (CPU-only)
- **Walltime**: 2 hours

## MinerU Command Reference

### Basic Usage
```bash
apptainer exec --nv mineru.sif mineru -p <input> -o <output>
```

### Command Options
- `-p, --path`: Input file path (PDF or image)
- `-o, --output`: Output directory path
- Models download automatically on first run

### Example Commands

#### Single Image
```bash
apptainer exec --nv \
    --bind ~/bl_goldstandard:/input:ro \
    --bind ~/output:/output \
    ~/projects/def-jic823/mineru/mineru.sif \
    mineru -p /input/image001.jpg -o /output/result
```

#### Single PDF
```bash
apptainer exec --nv \
    --bind ~/pdfs:/input:ro \
    --bind ~/output:/output \
    ~/projects/def-jic823/mineru/mineru.sif \
    mineru -p /input/document.pdf -o /output/result
```

## Monitoring Jobs

```bash
# Check job status
squeue -u $USER

# View live output
tail -f bl_test_mineru_<JOBID>.out

# Check GPU usage (when job is running)
ssh <compute-node>
nvidia-smi
```

## Performance Benchmarking

The British Library test generates detailed metrics:

1. **timing.csv**: Per-image processing time and exit codes
2. **failures.txt**: List of images that failed processing
3. **Success rate**: Percentage of successfully processed images

Compare MinerU results with OLMoCR to determine best tool for your use case.

## Troubleshooting

### Container Build Fails
- Check disk space: `df -h ~/projects/def-jic823/`
- Check build log: `cat build_mineru_*.err`
- Verify Apptainer version: `apptainer --version`
- Note: First build may take 30-60 minutes (downloads PyTorch + models)

### Out of Memory Errors
- Reduce batch size in script
- Increase `--mem` in SLURM header
- Use fewer CPU workers

### GPU Not Detected
- Verify `--nv` flag is present in apptainer command
- Check GPU allocation: `echo $CUDA_VISIBLE_DEVICES`
- Test with: `apptainer exec --nv mineru.sif nvidia-smi`

### Poor Quality on Historical Documents
- MinerU may struggle with degraded/faded text
- Consider trying OLMoCR for comparison
- Adjust input image DPI (higher = better quality, slower processing)

## Comparing with OLMoCR

You have experience with OLMoCR on Nibi. Key differences:

| Feature | MinerU | OLMoCR |
|---------|--------|--------|
| **Best for** | Tables, layout, formulas | General OCR, varied docs |
| **Speed** | ~12-24s/image (est.) | ~1.4 pages/sec |
| **Layout** | Excellent | Good |
| **Handwriting** | Poor | Better |
| **Historical** | TBD (test needed) | Proven good |

**Recommendation**: Run the BL gold standard test on both tools and compare quality metrics.

## Next Steps

1. ✅ Build container on Nibi
2. ✅ Run BL gold standard test (600 images)
3. Compare results with OLMoCR
4. Determine which tool to use for different document types
5. Scale to full collections

## File Locations Summary

### On Nibi
```
~/projects/def-jic823/mineru/
├── mineru.sif              # Apptainer container (built)
├── mineru.def              # Container definition
├── build_container.sh      # Build script
├── test_bl_newspapers.sh   # BL test script
├── batch_mineru.sh         # General batch script
├── bl_output/              # BL test results
├── bl_logs/                # BL test logs
├── pdfs/                   # General PDF input
└── output/                 # General output

~/bl_goldstandard/          # British Library images (600)
```

### On Local (WSL)
```
/home/jic823/MinerU/
├── nibi/                   # Nibi deployment files
├── docker/                 # Docker configs (reference)
├── slurm/                  # Generic SLURM template
└── README.md               # General documentation
```

## GitHub Repository
- **Repo**: `git@github.com:jburnford/minerU.git`
- **Branch**: `main`
- **Workflow**: Local development → push → pull on Nibi
