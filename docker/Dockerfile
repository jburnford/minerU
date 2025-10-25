# CUDA + PyTorch + MinerU image for H100 (CUDA 12)
FROM nvidia/cuda:12.1.1-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    PIP_NO_CACHE_DIR=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8 \
    TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0" \
    CUDA_HOME=/usr/local/cuda \
    FORCE_CUDA=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates wget build-essential pkg-config \
    python3 python3-pip python3-venv python3-dev \
    tesseract-ocr tesseract-ocr-eng libtesseract-dev \
    poppler-utils ghostscript \
    libgl1 libglib2.0-0 \
    fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

# Optional additional OCR languages (uncomment/install as needed)
# RUN apt-get update && apt-get install -y tesseract-ocr-deu tesseract-ocr-fra tesseract-ocr-spa tesseract-ocr-ita && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Install PyTorch CUDA build (12.1 wheels)
RUN pip3 install --upgrade pip setuptools wheel
RUN pip3 install --extra-index-url https://download.pytorch.org/whl/cu121 torch torchvision torchaudio

# Optional: ONNX Runtime GPU for some pipelines (kept separate due to CUDA compat)
RUN pip3 install onnx onnxruntime-gpu==1.18.0 || true

# Install MinerU and Python deps
COPY docker/requirements.txt /tmp/requirements.txt
RUN pip3 install -r /tmp/requirements.txt

# Copy entrypoint and scripts
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/run_mineru.py /usr/local/bin/run_mineru.py
RUN chmod +x /usr/local/bin/entrypoint.sh

# Default I/O locations (configurable via env)
ENV INPUT_PATH=/workspace/input \
    OUTPUT_PATH=/workspace/output \
    NUM_WORKERS=16 \
    MINERU_CMD=mineru

# Create mount points
RUN mkdir -p /workspace/input /workspace/output

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

