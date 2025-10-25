# MinerU on NIBI (H100)

This repo packages a production-ready setup to run MinerU on the DARC nibi cluster with H100 (80GB) GPUs. It includes:

- Docker image for CUDA 12 + PyTorch + MinerU
- Slurm batch script template for GPU jobs
- Kubernetes Job manifest with `nvidia.com/gpu` scheduling
- Wrapper scripts for batch processing document folders

Note: Cluster specifics vary. Pick the path (Slurm or Kubernetes) that matches how nibi is configured for you. The Docker image is common to both paths.

## Prerequisites

- H100 GPU nodes accessible on nibi
- Container runtime on the cluster
  - Kubernetes path: NVIDIA device plugin installed, `nvidia.com/gpu` available
  - Slurm path: Apptainer/Singularity or containerized jobs available
- A container registry you can push to and pull from (e.g. GHCR, ACR, ECR, GCR)

## Build the Docker image

1) Set environment values (or edit the Makefile):

```bash
cp .env.example .env
# edit .env with your registry, image, tag
```

2) Build and push:

```bash
make docker-build
make docker-push
```

The image contains CUDA 12, PyTorch w/ CUDA, and MinerU with OCR and PDF tooling. See `docker/Dockerfile` for details.

## Run locally (sanity check)

With an NVIDIA host and Docker configured for GPU:

```bash
# Single file or directory of PDFs/images
docker run --rm --gpus all \
  -v $(pwd)/sample_input:/workspace/input:ro \
  -v $(pwd)/sample_output:/workspace/output \
  --env INPUT_PATH=/workspace/input \
  --env OUTPUT_PATH=/workspace/output \
  ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
```

Input and output paths are configurable via env vars, see `scripts/entrypoint.sh`.

## Slurm (template)

If your nibi Slurm nodes use Apptainer/Singularity, submit:

```bash
sbatch slurm/mineru_run.sbatch
```

- Adjust partition, QoS, account, and constraints per your cluster
- Set `IMAGE_URI` inside the sbatch file or export it before submission
- Set input/output locations (e.g., shared filesystem or mounted project space)

## Kubernetes (template)

If your nibi uses Kubernetes with NVIDIA device plugin:

```bash
# Create storage (example PVC) or adapt to your storage class
kubectl apply -f k8s/pvc.yaml

# Update k8s/job-mineru.yaml image and paths, then
kubectl apply -f k8s/job-mineru.yaml
```

- Set `spec.template.spec.containers[0].image` to your pushed image
- Mount your datasets via PVCs, NFS, or object-store gateways as appropriate

## Performance guidance for H100

- Prefer GPU inference for layout/vision models; keep OCR GPU-enabled if supported
- Use half precision where available (AMP/FP16/BF16). H100 handles BF16 very well
- Batch by page where possible to maximize GPU utilization
- Keep CPU threads high (16–32) for I/O and PDF rendering
- Ensure XLA/TensorRT/ONNX acceleration is enabled if MinerU exposes it

## Configuration

- `scripts/run_mineru.py` wraps the MinerU CLI and accepts input/output arguments
- Set `MINERU_CMD` to override the executable if the CLI differs
- Place optional YAML config under `config/mineru.yaml` and pass `--config` if needed

## Historical documents tips

- Use high-quality PDF rendering (300–600 DPI) for scans
- Enable language packs in Tesseract if using CPU OCR (e.g., `tesseract-ocr-deu`, `-fra`)
- Consider larger layout models and table extractors; H100 (80GB) accommodates them comfortably
- Validate a small sample to tune thresholds (noise, bleed-through, gothic/Fraktur fonts)

## Repository layout

- `docker/Dockerfile`: Build environment with CUDA + PyTorch + MinerU
- `scripts/entrypoint.sh`: Container entrypoint to process a dataset
- `scripts/run_mineru.py`: Python wrapper calling MinerU CLI
- `slurm/mineru_run.sbatch`: Slurm template for H100 nodes
- `k8s/`: Example Kubernetes Job + PVC
- `config/mineru.yaml`: Optional advanced config (placeholder)

## Troubleshooting

- OOM on GPU: reduce per-batch pages, or downscale render DPI
- OCR errors on historical scripts: add language packs or specialized OCR models
- Import errors: ensure image matches CUDA/driver on the cluster; rebuild if driver/toolkit mismatch

