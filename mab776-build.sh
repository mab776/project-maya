#!/bin/sh
# mab776: build Maya's engine + vision encoder for sm_120 inside a throwaway CUDA 12.8 container (13.0.2 nvcc ICEs on glm_fast.cu: "Broken module found"), WITHOUT a GPU
# (Strata keeps serving). Same cmake flags as maya.py compile_engine/compile_vision; RAM-capped so nvcc
# can't squeeze strata-coder. Usage: ./mab776-build.sh   (log: build-mab776.log)
cd "$(dirname "$0")" || exit 1
COMMIT=$(sed -n 's/^LLAMA_CPP_COMMIT = "\(.*\)"/\1/p' setup.py)
docker run --rm --name maya-build --memory 10g --memory-swap 10g --cpus 6 \
  -v "$PWD":/maya -v "$PWD/../project-maya/third_party/llama.cpp":/maya/third_party/llama.cpp:ro -w /maya ${CUDA_IMAGE:-nvidia/cuda:12.8.1-devel-ubuntu24.04} bash -euc "
    trap 'chown -R $(id -u):$(id -g) /maya/build /maya/build-vision /maya/third_party 2>/dev/null' EXIT
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq && apt-get install -y -qq python3 python3-venv curl unzip g++ >/dev/null
    python3 -m venv /tmp/v && /tmp/v/bin/pip install -q cmake ninja
    export PATH=/tmp/v/bin:\$PATH
    if [ ! -d third_party/llama.cpp ]; then
      curl -sL https://github.com/ggml-org/llama.cpp/archive/$COMMIT.zip -o /tmp/l.zip
      unzip -q /tmp/l.zip -d /tmp/u && mv /tmp/u/llama.cpp-$COMMIT third_party/llama.cpp
    fi
    cmake -G Ninja -S . -B build -DCMAKE_BUILD_TYPE=Release -DSTRATA_ENABLE_CUDA=ON \
      -DCMAKE_CUDA_ARCHITECTURES=120 -DSTRATA_NATIVE_EXPERTS=ON -DSTRATA_BUILD_TESTS=OFF \
      -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc -DSTRATA_GGML_DIR=/maya/third_party/llama.cpp
    nice -n 19 cmake --build build --target strata -j 3
    exit 0  # mab776-116: vision unchanged, reuse ../project-maya build-vision
    python3 tools/vision/glm5next_patch.py third_party/llama.cpp
    cmake -G Ninja -S tools/vision -B build-vision -DCMAKE_BUILD_TYPE=Release \
      -DLLAMA_DIR=/maya/third_party/llama.cpp -DSTRATA_VISION_CUDA=ON \
      -DCMAKE_CUDA_ARCHITECTURES=120 -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc
    nice -n 19 cmake --build build-vision --target strata-vision -j 3
    echo BUILD_DONE
  " > build-mab776.log 2>&1
