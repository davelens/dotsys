# llama.cpp Gemma4 26B System Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the existing Ollama-based local LLM setup in `dotsys` with a repo-managed `llama.cpp` installation that serves `gemma-4-26B-A4B-it` on `127.0.0.1:11434/v1` on this Framework 16 Arch machine.

**Architecture:** Keep this work in `dotsys`, because the main changes are Arch provisioning and system service management. Build `llama.cpp` from source with AMD HIP and Vulkan support, install the resulting binaries into a stable system path, download the GGUF artifacts into a stable data directory, and manage runtime through a dedicated systemd service. Preserve the current port and 128k-oriented defaults so downstream tooling can swap from Ollama with minimal config churn.

**Tech Stack:** Arch Linux, Bash, `llama.cpp`, AMD ROCm/HIP, Vulkan, systemd, Hugging Face CLI.

---

## Machine Notes

- Host: Framework 16
- CPU: AMD Ryzen AI 9 HX 370
- iGPU: Radeon 890M (`gfx1150`)
- dGPU: Radeon RX 7600 XT class / Navi 33 (`gfx1102` in `rocminfo`)
- RAM: 64 GB DDR5
- OS: Arch Linux
- Existing local LLM setup lives in:
  - `arch/init.d/ollama.sh`
  - `arch/systemd/ollama.service.d/override.conf`
- Known working GPU targeting from current setup:
  - `HSA_OVERRIDE_GFX_VERSION=11.0.0`
  - `HIP_VISIBLE_DEVICES=0`
- Existing context target to preserve initially: `131072`

## Recommended Runtime Profile

- Build backends: HIP and Vulkan enabled together
- Primary runtime target: dGPU only
- Model source: `ggml-org/gemma-4-26B-A4B-it-GGUF`
- Model file: `gemma-4-26B-A4B-it-Q4_K_M.gguf`
- Vision projector: `mmproj-gemma-4-26B-A4B-it-f16.gguf`
- Install prefix: `/opt/llama.cpp`
- Model directory: `/var/lib/llama.cpp/models/gemma-4-26b-a4b-it`
- Service endpoint: `127.0.0.1:11434`
- API aliases: `gemma4,gemma4-128k`
- Initial context: `131072`
- Initial KV cache quantization: `q4_0` for K and V
- Initial batching: `256 / 64`

## File Structure

**Create:**
- `arch/bin/llama-cpp-build`
  Build helper that clones/updates `llama.cpp`, compiles for this machine, and installs binaries into `/opt/llama.cpp/bin`.
- `arch/bin/llama-cpp-fetch-gemma4`
  Downloads the exact Gemma4 26B GGUF artifacts into `/var/lib/llama.cpp/models/gemma-4-26b-a4b-it`.
- `arch/init.d/llama-cpp.sh`
  Main Arch setup script that installs build dependencies, creates the service account, builds binaries, downloads the model, installs the service, and starts it.
- `arch/systemd/llama-cpp-gemma4.service`
  System service definition for the OpenAI-compatible API.
- `arch/systemd/llama-cpp-gemma4.env`
  Runtime environment file copied to `/etc/llama-cpp/gemma4.env`.

**Modify:**
- `README.md`
  Add a short note that local LLM provisioning now lives in `arch/init.d/llama-cpp.sh` instead of `ollama.sh`.
- `arch/init.d/ollama.sh`
  Replace with a deprecation wrapper that explains the migration and delegates to `llama-cpp.sh`.

**Delete:**
- `arch/systemd/ollama.service.d/override.conf`
  No longer needed once the service is `llama.cpp`-managed.

### Task 1: Add Repeatable Build and Download Helpers

**Files:**
- Create: `arch/bin/llama-cpp-build`
- Create: `arch/bin/llama-cpp-fetch-gemma4`

- [ ] **Step 1: Create `arch/bin/llama-cpp-build`**

```bash
#!/usr/bin/env bash
set -euo pipefail

src_dir="/usr/local/src/llama.cpp"
build_dir="${src_dir}/build"
install_dir="/opt/llama.cpp"

sudo mkdir -p /usr/local/src "${install_dir}/bin"

if [ ! -d "${src_dir}/.git" ]; then
  sudo git clone https://github.com/ggml-org/llama.cpp "${src_dir}"
else
  sudo git -C "${src_dir}" pull --ff-only
fi

sudo cmake -S "${src_dir}" -B "${build_dir}" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_HIP=ON \
  -DGGML_VULKAN=ON \
  -DGPU_TARGETS="gfx1102;gfx1150" \
  -DCMAKE_INSTALL_PREFIX="${install_dir}"

sudo cmake --build "${build_dir}" --target llama-cli llama-server llama-bench -j "$(nproc)"

sudo install -m 0755 "${build_dir}/bin/llama-cli" "${install_dir}/bin/llama-cli"
sudo install -m 0755 "${build_dir}/bin/llama-server" "${install_dir}/bin/llama-server"
sudo install -m 0755 "${build_dir}/bin/llama-bench" "${install_dir}/bin/llama-bench"
```

- [ ] **Step 2: Create `arch/bin/llama-cpp-fetch-gemma4`**

```bash
#!/usr/bin/env bash
set -euo pipefail

model_dir="/var/lib/llama.cpp/models/gemma-4-26b-a4b-it"

sudo mkdir -p "${model_dir}"
sudo huggingface-cli download ggml-org/gemma-4-26B-A4B-it-GGUF \
  gemma-4-26B-A4B-it-Q4_K_M.gguf \
  mmproj-gemma-4-26B-A4B-it-f16.gguf \
  --local-dir "${model_dir}"

sudo chown -R llama-cpp:llama-cpp /var/lib/llama.cpp
```

- [ ] **Step 3: Validate the helpers manually before wiring them into init.d**

Run:

```bash
chmod +x arch/bin/llama-cpp-build arch/bin/llama-cpp-fetch-gemma4
sudo pacman -S --needed --noconfirm cmake ninja git python python-huggingface-hub vulkan-tools shaderc
./arch/bin/llama-cpp-build
sudo useradd --system --create-home --home-dir /var/lib/llama.cpp --shell /usr/bin/nologin llama-cpp || true
./arch/bin/llama-cpp-fetch-gemma4
sudo /opt/llama.cpp/bin/llama-cli --version
sudo /opt/llama.cpp/bin/llama-cli --list-devices
```

Expected:
- the binaries exist under `/opt/llama.cpp/bin`
- the device list includes the AMD dGPU
- the model directory contains the two expected GGUF files

- [ ] **Step 4: Commit the helpers**

```bash
git add arch/bin/llama-cpp-build arch/bin/llama-cpp-fetch-gemma4
git commit -m "arch/bin: add llama.cpp build and model fetch helpers"
```

### Task 2: Add the Runtime Service and Env File

**Files:**
- Create: `arch/systemd/llama-cpp-gemma4.service`
- Create: `arch/systemd/llama-cpp-gemma4.env`

- [ ] **Step 1: Create `arch/systemd/llama-cpp-gemma4.env`**

```bash
HSA_OVERRIDE_GFX_VERSION=11.0.0
HIP_VISIBLE_DEVICES=0

LLAMA_CPP_MODEL=/var/lib/llama.cpp/models/gemma-4-26b-a4b-it/gemma-4-26B-A4B-it-Q4_K_M.gguf
LLAMA_CPP_MMPROJ=/var/lib/llama.cpp/models/gemma-4-26b-a4b-it/mmproj-gemma-4-26B-A4B-it-f16.gguf

LLAMA_ARG_HOST=127.0.0.1
LLAMA_ARG_PORT=11434
LLAMA_ARG_ALIAS=gemma4,gemma4-128k
LLAMA_ARG_CTX_SIZE=131072
LLAMA_ARG_CACHE_TYPE_K=q4_0
LLAMA_ARG_CACHE_TYPE_V=q4_0
LLAMA_ARG_BATCH_SIZE=256
LLAMA_ARG_UBATCH_SIZE=64
LLAMA_ARG_PARALLEL=1
LLAMA_ARG_N_GPU_LAYERS=999
```

- [ ] **Step 2: Create `arch/systemd/llama-cpp-gemma4.service`**

```ini
[Unit]
Description=llama.cpp Gemma4 26B local API
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=llama-cpp
Group=llama-cpp
SupplementaryGroups=render video
WorkingDirectory=/var/lib/llama.cpp
EnvironmentFile=/etc/llama-cpp/gemma4.env
ExecStart=/opt/llama.cpp/bin/llama-server \
  --model ${LLAMA_CPP_MODEL} \
  --mmproj ${LLAMA_CPP_MMPROJ} \
  --host ${LLAMA_ARG_HOST} \
  --port ${LLAMA_ARG_PORT} \
  --alias ${LLAMA_ARG_ALIAS} \
  --ctx-size ${LLAMA_ARG_CTX_SIZE} \
  --cache-type-k ${LLAMA_ARG_CACHE_TYPE_K} \
  --cache-type-v ${LLAMA_ARG_CACHE_TYPE_V} \
  --batch-size ${LLAMA_ARG_BATCH_SIZE} \
  --ubatch-size ${LLAMA_ARG_UBATCH_SIZE} \
  --parallel ${LLAMA_ARG_PARALLEL} \
  --n-gpu-layers ${LLAMA_ARG_N_GPU_LAYERS}
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
```

- [ ] **Step 3: Install the service assets manually once before automating them**

Run:

```bash
sudo mkdir -p /etc/llama-cpp
sudo cp arch/systemd/llama-cpp-gemma4.env /etc/llama-cpp/gemma4.env
sudo cp arch/systemd/llama-cpp-gemma4.service /etc/systemd/system/llama-cpp-gemma4.service
sudo systemctl daemon-reload
sudo systemctl enable --now llama-cpp-gemma4.service
sudo systemctl status --no-pager llama-cpp-gemma4.service
```

Expected:
- the service reaches `active (running)`
- logs show `llama-server` listening on `127.0.0.1:11434`

- [ ] **Step 4: Validate the API directly**

Run:

```bash
curl -fsS http://127.0.0.1:11434/v1/models | python -m json.tool

curl -fsS http://127.0.0.1:11434/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gemma4-128k",
    "messages": [{"role": "user", "content": "Reply with exactly: llama.cpp is live"}],
    "max_tokens": 32
  }' | python -c 'import json,sys; print(json.load(sys.stdin)["choices"][0]["message"]["content"])'
```

Expected:
- `/v1/models` includes `gemma4` and `gemma4-128k`
- the completion prints `llama.cpp is live`

- [ ] **Step 5: Commit the service assets**

```bash
git add arch/systemd/llama-cpp-gemma4.env arch/systemd/llama-cpp-gemma4.service
git commit -m "arch/systemd: add llama.cpp Gemma4 service"
```

### Task 3: Replace the Existing Ollama Provisioning Entry Point

**Files:**
- Create: `arch/init.d/llama-cpp.sh`
- Modify: `arch/init.d/ollama.sh`
- Delete: `arch/systemd/ollama.service.d/override.conf`

- [ ] **Step 1: Create `arch/init.d/llama-cpp.sh`**

```bash
#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

echo "==> Setting up llama.cpp with Gemma4 26B..."

sudo pacman -S --needed --noconfirm \
  git cmake ninja python python-huggingface-hub \
  vulkan-tools shaderc

sudo useradd --system --create-home --home-dir /var/lib/llama.cpp \
  --shell /usr/bin/nologin llama-cpp || true

sudo usermod -aG render,video llama-cpp

"$DOTSYS_REPO_HOME/arch/bin/llama-cpp-build"
"$DOTSYS_REPO_HOME/arch/bin/llama-cpp-fetch-gemma4"

sudo mkdir -p /etc/llama-cpp
sudo cp "$DOTSYS_REPO_HOME/arch/systemd/llama-cpp-gemma4.env" /etc/llama-cpp/gemma4.env
sudo cp "$DOTSYS_REPO_HOME/arch/systemd/llama-cpp-gemma4.service" /etc/systemd/system/llama-cpp-gemma4.service

sudo systemctl daemon-reload
sudo systemctl enable --now llama-cpp-gemma4.service

echo "==> llama.cpp Gemma4 service is running on port 11434."
```

- [ ] **Step 2: Turn `arch/init.d/ollama.sh` into a migration wrapper instead of deleting it immediately**

Replace the file with:

```bash
#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

echo "==> Ollama provisioning was replaced by llama.cpp. Delegating to llama-cpp.sh..."
exec "$DOTSYS_REPO_HOME/arch/init.d/llama-cpp.sh"
```

- [ ] **Step 3: Delete the obsolete Ollama override file**

Delete:

```text
arch/systemd/ollama.service.d/override.conf
```

- [ ] **Step 4: Run the migrated entry point end-to-end**

Run:

```bash
./arch/init.d/ollama.sh
sudo systemctl status --no-pager llama-cpp-gemma4.service
curl -fsS http://127.0.0.1:11434/v1/models | python -m json.tool
```

Expected:
- the wrapper message is printed
- the new service is active
- the models endpoint returns data

- [ ] **Step 5: Commit the provisioning migration**

```bash
git add arch/init.d/llama-cpp.sh arch/init.d/ollama.sh
git rm arch/systemd/ollama.service.d/override.conf
git commit -m "arch/init.d: replace ollama setup with llama.cpp"
```

### Task 4: Update Repo Documentation and Record Baseline Performance

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add a short local-LLM setup note to `README.md`**

Add this section after the opening description:

```md
## Local LLM setup

Arch local LLM provisioning lives in `arch/init.d/llama-cpp.sh`.
It installs a system `llama.cpp` build plus the `gemma-4-26B-A4B-it` GGUF model,
then exposes an OpenAI-compatible API on `127.0.0.1:11434`.
```

- [ ] **Step 2: Record a baseline benchmark on the target machine**

Run:

```bash
sudo /opt/llama.cpp/bin/llama-bench \
  -m /var/lib/llama.cpp/models/gemma-4-26b-a4b-it/gemma-4-26B-A4B-it-Q4_K_M.gguf \
  -ngl 999 \
  -ctk q4_0 \
  -ctv q4_0 \
  -ub 64 \
  -b 256
```

Expected:
- benchmark output completes without HIP load or OOM errors

- [ ] **Step 3: Apply the fallback profile only if the 128k service is unstable**

If startup or generation fails under `131072`, update `/etc/llama-cpp/gemma4.env` to:

```bash
LLAMA_ARG_CTX_SIZE=65536
LLAMA_ARG_BATCH_SIZE=128
LLAMA_ARG_UBATCH_SIZE=32
```

Then run:

```bash
sudo systemctl restart llama-cpp-gemma4.service
sudo systemctl status --no-pager llama-cpp-gemma4.service
```

Do not apply this fallback pre-emptively.

- [ ] **Step 4: Commit the documentation update**

```bash
git add README.md
git commit -m "arch: document llama.cpp local LLM setup"
```

## Verification Checklist

- `sudo /opt/llama.cpp/bin/llama-cli --list-devices`
- `sudo systemctl status --no-pager llama-cpp-gemma4.service`
- `curl -fsS http://127.0.0.1:11434/v1/models | python -m json.tool`
- `curl -fsS http://127.0.0.1:11434/v1/chat/completions ...`
- `sudo /opt/llama.cpp/bin/llama-bench ...`

## Notes for the Implementing Model

- Keep this work in `dotsys`; downstream editor config changes belong in `dotfiles`, but the machine provisioning and service ownership belong here.
- Preserve the current port `11434` so this remains a drop-in Ollama replacement from the client side.
- Preserve `HSA_OVERRIDE_GFX_VERSION=11.0.0` unless `llama.cpp` on the target build proves it is no longer required for this ROCm stack.
- The current `ollama.sh` entry point is a concrete compatibility need, so a delegating wrapper is preferred over immediate deletion.
