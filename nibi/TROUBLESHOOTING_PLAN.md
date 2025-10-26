# MinerU on Nibi: Comprehensive Troubleshooting Plan

## Current Status
- **Issue**: GLIBC_ABI_DT_RELR compatibility error with OpenCV
- **Root Cause**: Ubuntu 22.04 container on AlmaLinux 9.6 host
- **Current Fix**: Rebuilding with Rocky Linux 9 base image

## Research Summary

### 1. MinerU Architecture & Requirements

#### Backends
MinerU supports two inference backends:
- **Pipeline Backend**: CPU inference, no GPU required, slower
- **vLLM Backend**: GPU acceleration, 20-30x faster than pipeline backend

#### GPU Requirements (vLLM)
- **Architecture**: Turing or newer (RTX 2000 series+)
- **VRAM**: Minimum 8GB
- **CUDA**: Driver supporting CUDA 12.8+
- **Compute Capability**: 7.5+ (H100 is 9.0, so we're good)

#### Dependencies
- PyTorch with CUDA support
- OpenCV (cv2)
- detectron2 (for layout detection)
- vLLM inference engine
- ONNX Runtime GPU

### 2. Known Compatibility Issues

#### GLIBC Issues on HPC Clusters
**Problem**: Software compiled with newer GLIBC fails on clusters with older OS
- AlmaLinux 9: GLIBC 2.34
- Ubuntu 22.04: GLIBC 2.35+
- OpenCV requires libgcc-ng with __glibc>=2.17

**Solution**: Match container OS to host OS

#### Apptainer --nv GPU Binding Issues
**Problem**: `--nv` flag binds incompatible host GPU libraries into container
- Error: `GLIBC_2.34 not found (required by libGLX.so.0)`
- Cause: Host NVIDIA drivers built against newer GLIBC than container

**Solutions**:
1. **System-wide fix** (requires admin):
   - Edit `/etc/apptainer/nvliblist.conf`
   - Remove lines: libGLX.so, libGLX.so.0, libglx.so, libglx.so.0, libGLdispatch.so
   - **Warning**: Affects all containers system-wide

2. **Container OS matching** (our approach):
   - Use RHEL-based container (Rocky/Alma) for RHEL hosts
   - Ensures GLIBC compatibility

#### PyTorch 2.8.0 Compatibility
- MinerU had issues with PyTorch 2.8.0 and pipeline backend
- Fixed in recent versions
- Recommended: Use PyTorch 2.7.1 if issues persist

#### Windows Installation
- MinerU 2.0+ cannot install on Windows
- sgl-kernel lacks Windows wheels
- Solution: Use WSL2 or Linux

### 3. Pre-built Docker Images

#### Community Images on Docker Hub
- `quincyqiang/mineru:0.1-models`, `0.2-models`, `0.3-models`
- `jianjungki/mineru:latest`
- `alexsuntop/mineru`

#### Official Docker Approach
- Base: `vllm/vllm-openai:v0.10.1.1` (or `v0.10.2` for older GPUs)
- Includes vLLM inference framework
- Pre-configured for GPU acceleration

## Failure Response Plan

### If Current Rebuild Fails

#### Option 1: Pull Pre-built Docker Image
```bash
# On Nibi, pull a working MinerU image
apptainer pull mineru_prebuilt.sif docker://quincyqiang/mineru:latest

# Test immediately
apptainer exec --nv mineru_prebuilt.sif mineru -p <test.pdf> -o <output>
```

**Pros**:
- Fast, no build time
- Community-tested
- May already handle GLIBC issues

**Cons**:
- Unknown base OS
- May not match Nibi's environment
- Less control over dependencies

#### Option 2: Use Official vLLM Base Image
```bash
# Pull vLLM image and convert to Apptainer
apptainer pull vllm_base.sif docker://vllm/vllm-openai:v0.10.2

# Test GPU access
apptainer exec --nv vllm_base.sif nvidia-smi

# Install MinerU manually inside
apptainer shell --writable-tmpfs --nv vllm_base.sif
pip install uv
uv pip install --system "mineru[core]"
```

**Pros**:
- Official vLLM base (same as MinerU Docker)
- Known GPU compatibility
- vLLM 0.10.2 supports Turing+ GPUs

**Cons**:
- Still might have GLIBC issues
- Requires writable overlay for pip installs

#### Option 3: Modify nvliblist.conf (Requires Admin)
If we have sudo/admin access to Nibi:
```bash
# Backup original
sudo cp /etc/apptainer/nvliblist.conf /etc/apptainer/nvliblist.conf.bak

# Edit file and remove problematic libraries:
# - libGLX.so
# - libGLX.so.0
# - libglx.so
# - libglx.so.0
# - libGLdispatch.so

# Rebuild container with original Ubuntu base
```

**Pros**:
- Fixes --nv binding issues permanently
- Works with any Ubuntu-based container

**Cons**:
- Requires root access
- System-wide change (affects all users)
- Potential side effects

#### Option 4: Use Pipeline Backend (No GPU)
If GPU issues persist, fall back to CPU inference:
```bash
# Set environment variable to force pipeline backend
export MINERU_BACKEND=pipeline

# Or add to container definition
%environment
    export MINERU_BACKEND=pipeline
```

**Pros**:
- No GPU dependencies
- No GLIBC/libGL issues
- Will definitely work

**Cons**:
- 20-30x slower than vLLM
- Not suitable for 600+ image batches

#### Option 5: Build Minimal Container
Create absolute minimal container with only essentials:
```singularity
Bootstrap: docker
From: nvidia/cuda:12.1.1-base-rockylinux9

%post
    # Minimal system packages
    dnf install -y python3 python3-pip

    # Install MinerU with CPU-only dependencies
    pip3 install --no-deps mineru
    pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cpu

    # Add GPU support separately
    pip3 install opencv-python-headless  # Headless = no GUI libs
```

**Pros**:
- Minimal dependencies = fewer conflicts
- opencv-python-headless avoids libGL issues

**Cons**:
- May be missing features
- Requires careful dependency management

### Diagnostic Steps

#### 1. Container Build Analysis
```bash
# Check build log for specific failures
cat build_mineru_*.err | grep -i "error\|failed"

# Look for package installation issues
cat build_mineru_*.out | grep -i "could not\|unable"

# Check final container size (should be ~10-15GB)
ls -lh mineru.sif
```

#### 2. GPU Access Test
```bash
# Test basic GPU binding
apptainer exec --nv mineru.sif nvidia-smi

# Test CUDA availability
apptainer exec --nv mineru.sif python3 -c "import torch; print(torch.cuda.is_available())"

# Check CUDA version
apptainer exec --nv mineru.sif python3 -c "import torch; print(torch.version.cuda)"
```

#### 3. Library Compatibility Check
```bash
# Check GLIBC version in container
apptainer exec mineru.sif ldd --version

# Check host GLIBC
ldd --version

# Test OpenCV import
apptainer exec --nv mineru.sif python3 -c "import cv2; print(cv2.__version__)"

# List bound libraries with --nv
apptainer exec --nv mineru.sif ls -la /.singularity.d/libs/
```

#### 4. MinerU Import Test
```bash
# Test basic import
apptainer exec mineru.sif python3 -c "import mineru; print('Success')"

# Test with GPU
apptainer exec --nv mineru.sif python3 -c "from mineru.cli import client; print('Success')"

# Check installed version
apptainer exec mineru.sif python3 -c "import mineru; print(mineru.__version__)"
```

### Error Pattern Recognition

#### GLIBC Errors
**Pattern**: `version 'GLIBC_X.XX' not found`
**Action**: Container OS mismatch → rebuild with matching OS

#### OpenCV Errors
**Pattern**: `ImportError: libGL.so.1` or `cv2.error`
**Action**: GPU library binding issue → try nvliblist.conf fix or opencv-headless

#### CUDA Errors
**Pattern**: `CUDA driver version is insufficient`
**Action**: Check CUDA compatibility, try different PyTorch version

#### vLLM Errors
**Pattern**: `compute capability` or `architecture not supported`
**Action**: Try vllm-openai:v0.10.2 base image (better Turing support)

#### Memory Errors
**Pattern**: `can't allocate memory` or `OOM`
**Action**: Reduce batch size, increase SLURM memory allocation

## Testing Strategy

### Phase 1: Basic Container Validation
1. Container builds without errors
2. Python imports work
3. MinerU command exists

### Phase 2: GPU Access
1. nvidia-smi works with --nv
2. CUDA available in PyTorch
3. No GLIBC errors with --nv

### Phase 3: MinerU Functionality
1. Import mineru.cli.client succeeds
2. mineru --help works
3. Process single small image (test.jpg)

### Phase 4: Real Workload
1. Process your test PDF (cu31924075428817.pdf)
2. Check output quality
3. Measure performance

### Phase 5: Scale Test
1. Process 10 PDFs
2. Process 100 images
3. Full BL gold standard (600 images)

## Fallback Decision Tree

```
Build Succeeds?
├─ YES → Test GPU access
│   ├─ GPU Works → Test MinerU
│   │   ├─ MinerU Works → DONE! 🎉
│   │   └─ MinerU Fails → Check import errors
│   │       ├─ GLIBC error → Try nvliblist.conf fix
│   │       ├─ Model download error → Check internet/firewall
│   │       └─ Other → Try pre-built image (Option 1)
│   └─ GPU Fails (GLIBC) → Try nvliblist.conf fix
│       ├─ Fixed → Retest
│       └─ Still fails → Try pre-built image (Option 1)
└─ NO → Check build logs
    ├─ DNF/package errors → Fix package names for Rocky
    ├─ PyTorch install fails → Try different CUDA index
    ├─ MinerU install fails → Check network, try git install
    └─ Out of memory → Increase build job memory
```

## Performance Expectations

### With GPU (vLLM Backend)
- **Single PDF (100 pages)**: 1-2 minutes
- **Single image**: 2-5 seconds
- **600 images (BL test)**: 30-60 minutes
- **Throughput**: ~10-20 pages/minute

### Without GPU (Pipeline Backend)
- **Single PDF (100 pages)**: 20-60 minutes
- **Single image**: 30-120 seconds
- **600 images**: 5-20 hours
- **Throughput**: ~0.5-2 pages/minute

## Success Criteria

### Minimum Viable
- ✅ Container builds
- ✅ MinerU processes one PDF successfully
- ✅ Output is readable markdown/JSON

### Full Success
- ✅ GPU acceleration working
- ✅ No GLIBC errors
- ✅ Processes BL gold standard (600 images)
- ✅ Performance meets expectations (~2-4 hours for 600 images)
- ✅ Output quality acceptable for historical documents

## Next Actions After This Build

1. **If build succeeds**: Run diagnostic tests (Phase 1-2)
2. **If build fails**: Analyze logs, try Option 1 (pre-built image)
3. **If GPU issues**: Try nvliblist.conf fix or Option 2 (vLLM base)
4. **If all GPU attempts fail**: Accept CPU-only (Option 4)

## Long-term Recommendations

### For Production Use
1. **Document working configuration**: OS versions, package versions, exact build steps
2. **Create versioned containers**: Tag with date and MinerU version
3. **Test before major updates**: PyTorch/CUDA updates can break things
4. **Have CPU fallback**: Pipeline backend as backup
5. **Monitor performance**: Track pages/minute, GPU utilization

### For Large-scale Processing
1. **Batch optimization**: Group similar-sized documents
2. **Resource tuning**: Memory, CPU cores, GPU memory utilization
3. **Parallel processing**: Multiple containers on multiple GPUs
4. **Error handling**: Retry failed documents, log all failures
5. **Quality checks**: Spot-check outputs, compare with OLMoCR

## Contact/Support Resources

- **MinerU GitHub**: https://github.com/opendatalab/MinerU/issues
- **Documentation**: https://opendatalab.github.io/MinerU/
- **Apptainer Docs**: https://apptainer.org/docs/
- **Our OLMoCR Experience**: Proven success with H100 + Apptainer on Nibi
