#!/bin/bash
# DevContainer 内での高速な GUI 確認（Linux のみ・数秒〜数十秒）
#  1. pytest-qt による UI テスト（pytest-xvfb が自動で仮想ディスプレイを起動）
#  2. アプリを実際に起動してスクリーンショットを保存
# 結果: artifacts/screenshots/local/*.png
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=artifacts/screenshots/local
rm -rf "$OUT"
mkdir -p "$OUT"

uv run pytest --screenshot-dir "$OUT" "$@"
xvfb-run -a uv run python -m myapp --smoke-test "$OUT/app_smoke.png"

echo "スクリーンショット:"
ls -1 "$OUT"
