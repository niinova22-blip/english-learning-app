#!/usr/bin/env bash
# Fetches the pinned on-device tutor model (MLX-format, 4-bit
# quantized Llama 3.2 3B Instruct) from Hugging Face into the App's
# bundled resources directory, if not already present at that exact
# revision. Run before building the App target — see
# .github/workflows/app-build.yml.
#
# The destination directory is git-ignored: this ~1.5-2GB weight file
# is too large for a normal git commit (GitHub's 100MB per-file limit)
# and isn't worth Git LFS's bandwidth-quota risk on a public repo.
#
# Usage: scripts/fetch-tutor-model.sh (run from the repo root)
set -euo pipefail

MODEL_REPO="mlx-community/Llama-3.2-3B-Instruct-4bit"
MODEL_REVISION="7f0dc925e0d0afb0322d96f9255cfddf2ba5636e"
DEST_DIR="App/Sources/EnglishApp/Resources/TutorModel"

if [ -f "$DEST_DIR/.fetched-revision" ] && [ "$(cat "$DEST_DIR/.fetched-revision")" = "$MODEL_REVISION" ]; then
  echo "Tutor model already present at revision $MODEL_REVISION — skipping download."
  exit 0
fi

python3 -m pip install --quiet --upgrade --break-system-packages huggingface_hub

rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"

# Recent huggingface_hub releases replaced the `huggingface-cli` entry
# point with a new `hf` command (huggingface-cli now just prints a
# deprecation notice and exits non-zero). Prefer `hf` when present, fall
# back to `huggingface-cli`, and finally to invoking the module directly
# in case neither console script landed on PATH (seen in some Git Bash /
# pip --user setups on Windows).
if command -v hf >/dev/null 2>&1; then
  hf download "$MODEL_REPO" \
    --revision "$MODEL_REVISION" \
    --local-dir "$DEST_DIR"
elif command -v huggingface-cli >/dev/null 2>&1; then
  huggingface-cli download "$MODEL_REPO" \
    --revision "$MODEL_REVISION" \
    --local-dir "$DEST_DIR"
else
  python3 -m huggingface_hub.commands.huggingface_cli download "$MODEL_REPO" \
    --revision "$MODEL_REVISION" \
    --local-dir "$DEST_DIR"
fi

echo "$MODEL_REVISION" > "$DEST_DIR/.fetched-revision"
echo "Fetched tutor model: $(du -sh "$DEST_DIR" | cut -f1)"
