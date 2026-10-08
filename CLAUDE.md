# プロジェクト概要

PySide6 (Qt6) による Windows / Linux 両対応の GUI アプリ。
ソースは `src/myapp/`、UI テストは `tests/`（pytest-qt）。

# Python 環境

パッケージ管理は uv。依存の追加は `uv add <pkg>`（開発用は `uv add --dev <pkg>`）で行い、
`pyproject.toml` と `uv.lock` を両方コミットする。pip は使わない。
コマンドは `uv run ...` 経由で実行する。

# 開発ループ（この順で作業すること）

1. コードを修正する。UI を変えたら `tests/` に対応するテストと `screenshot(...)` 呼び出しを追加する。
2. ローカル確認: `scripts/local-gui-check.sh` を実行し、
   `artifacts/screenshots/local/*.png` を **画像として開いて見た目を確認** する
   （文字切れ・重なり・はみ出し・日本語の文字化けがないか）。
3. 問題なければコミットし、push の許可をユーザーに求める。
4. push 後、両 OS の検証結果を取得する:
   ```bash
   RUN_ID=$(gh run list --branch "$(git branch --show-current)" --limit 1 --json databaseId --jq '.[0].databaseId')
   gh run watch "$RUN_ID" --exit-status
   gh run download "$RUN_ID" -D "artifacts/ci/$RUN_ID"
   ```
   失敗時は `gh run view "$RUN_ID" --log-failed` でログを確認する。
5. `artifacts/ci/<RUN_ID>/gui-results-linux/` と `gui-results-windows/` のスクリーンショットを
   **両方とも画像として確認** し、OS 間の見た目の差異も報告する。

# 守ること

- `.github/workflows/`、`runner/`、`.devcontainer/`、`.claude/settings.json` は編集しない
  （変更が必要な場合は理由と差分案をユーザーに提示する）。
- ネットワークは許可リスト方式で制限されている。外部サイトへの接続失敗は仕様であり、回避しようとしないこと。
- Windows 固有の API・パス区切り・フォントなどに依存するコードを書く場合は、両 OS で動くよう分岐させる。
