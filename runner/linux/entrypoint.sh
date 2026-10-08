#!/bin/bash
# JIT 設定（1回限りの登録情報）でランナーを起動し、1ジョブ終えたら終了する
set -euo pipefail
: "${RUNNER_JITCONFIG:?RUNNER_JITCONFIG が設定されていません}"
cfg="$RUNNER_JITCONFIG"
unset RUNNER_JITCONFIG   # ジョブの環境変数から見えないようにする
cd /home/runner/actions-runner
exec ./run.sh --jitconfig "$cfg"
