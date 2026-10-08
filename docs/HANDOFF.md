# 引き継ぎメモ：Claude Code 用 DevContainer + Podman 隔離環境

claude.ai のチャットで設計・構築してきた内容の引き継ぎ。Claude Code はこのファイルを最初に読むこと。

## 目的

- Windows / Linux 両対応の GUI アプリ（PySide6）を、Claude Code を隔離環境に閉じ込めた状態で開発する。
- GUI の動作確認（スクリーンショット取得と目視確認）まで Claude Code に自動化させる。
- 開発は DevContainer、Linux/Windows の検証とビルドは GitHub Actions のセルフホストランナーで行う。

## 決定事項

| 項目 | 決定 |
|---|---|
| コンテナ基盤 | 開発PCの Podman Desktop（WSL2 上の Podman machine）。DevContainer と Linux ランナーは同じ machine 上の別コンテナ。**Podman は必須** |
| GUI フレームワーク | Qt / PySide6、テストは pytest-qt、配布ビルドは PyInstaller |
| Python 環境 | uv（`[dependency-groups]`、`.python-version` = 3.12、CI は `uv sync --locked`） |
| 外向き通信 | DevContainer 内で iptables + ipset の許可リスト（Anthropic 公式リファレンス構成ベース） |
| 開発⇔検証の連携 | GitHub 経由のみ（push → Actions → `gh run download` でスクショ取得）。Claude は検証環境に直接触れない |
| Linux ランナー | Podman の使い捨てコンテナ、JIT 登録、`--cap-drop=ALL`、Podman ソケットは渡さない |
| Windows ランナー | ログオン中のデスクトップセッションで実行（サービス化しない）。別PC/VM 推奨（未確定） |
| 権限分離 | Claude 用トークンは Contents/Actions のみ（Workflows 権限なし）。ランナー登録用トークンはホスト側のみ |

## 開発PCの環境（確認済みの事実）

- VS Code 1.141.0 / Dev Containers 0.469.0（同梱 CLI 0.89.0）/ Podman 5.8.3（クライアント・サーバーとも）
- Podman 既定接続は `claudeVM-root`（**rootful**、`ssh://root@127.0.0.1:58105/run/podman/podman.sock`）。podman コマンド1回あたり約 300ms
- Podman machine `claudeVM` の events_logger は `journald`、cgroup_manager は `cgroupfs`。`/etc/containers/containers.conf.d/` は無し
- WSL ディストリ: `Ubuntu`（**既定 `*`**、Ubuntu 26.04.1 LTS、2026-10-08 追加）、`podman-claudeVM`、`podman-machine-default`
  - 既定を戻す場合: `wsl --set-default podman-claudeVM`
- `dev.containers.executeInWSL` はオフ
- ワークスペースは Windows 側（`C:\Users\...\VScode\gui-app-env`）

## これまでに発生した問題と対処

1. **apt-get update 失敗（Yarn リポジトリの署名鍵）**
   ベースイメージ `mcr.microsoft.com/devcontainers/python` 同梱の Yarn apt リポジトリが原因。
   → Dockerfile で `/etc/apt/sources.list.d/yarn*.list` を削除して解決済み。
2. **`--userns=keep-id`**
   rootless 前提で入れていたが、接続が rootful のため削除済み（rootless に移る場合のみ再追加）。
3. **「Container started」のまま接続が進まない（原因特定・回避中。2026-10-08 時点で接続できている）**
   - 当初の見立て（既定 WSL ディストリ＝Podman machine で userEnvProbe が止まる）は**誤り**だった。
     Ubuntu を既定にした後も同じ行で止まった。userEnvProbe は「Container started」より前の処理で、Ubuntu 上で 0.1 秒で完了している。
     Ubuntu を既定にしたこと自体は無害なのでそのままにしている。
   - **本当の原因（ほぼ確定）**: Dev Containers CLI の競合。CLI は `podman events --format json --filter event=start` を起動した約 20ms 後に `podman run` を起動し、
     start イベントが届くのを待つ（`devContainersSpecCLI.js` の `startEventSeen`。タイムアウト無し、`--since` 無し）。
     ssh 経由の `podman events` の購読が始まる前にコンテナが起動すると、start イベントを取り逃がして永久に待つ。
   - 証拠: CLI を `--log-level trace` で直接実行すると、止まった回は `Log: startEventSeen#data` が1行も出ない。成功した回は「Container started」の約 0.4 秒後に届いている。
     イベント自体は journald に記録されている（`podman events --stream=false` で確認できる）。
   - 再現率は**一定しない**: VS Code からは 2/2 回止まった。CLI 直接実行では 1/2 回止まり、その後 4 回連続は成功した（その間は 0/4）。
     Machine 内でローカル実行した場合は、journald・file のどちらでも取り逃がさなかった。
   - その後、VS Code からの Reopen / Rebuild は2回とも接続できた（1回目は既に動いていたコンテナを使ったので、イベント待ちは通っていない）。
   - **当面の運用**: 「Container started」で1分以上止まったら、ウィンドウを閉じて再実行する。頻発するようなら下の b → c を試す。
   - **対処案（未実施）**
     a. VS Code から再試行する（上記の運用）
     b. Machine の events_logger を `file` にして比べる（`/etc/containers/containers.conf.d/` に drop-in を置き、podman.service を再起動。他の DevContainer の接続が切れる点に注意）
     c. `dev.containers.dockerPath` に、`run` のときだけ約 1.5 秒待ってから podman.exe を呼ぶ小さなラッパー exe を指定する（確実だが部品が増える。.cmd は改行を含む引数を渡せないので不可）
   - 応急処置: `dev.containers.defaultUserEnvProbe` を `none` にしても**この問題には効かない**。
4. **ファイアウォールが別のスクリプトで動いていた（解決済み・2026-10-08）**
   `claude-code` feature（v1.0.5）がインストール時に、自前の参照版を `/usr/local/bin/init-firewall.sh` にコピーする。
   feature は Dockerfile の後に実行されるので、リポジトリ版が上書きされていた。
   参照版は名前解決できないドメインがあると終了するので、`statsig.anthropic.com` で postStartCommand が失敗していた。
   → リポジトリ版を `/usr/local/bin/gui-app-firewall.sh` という別名でコピーし、postStartCommand と sudoers もこのパスに変更。
   起動ログで `[firewall] OK` を確認済み（`statsig.anthropic.com` は WARN でスキップ）。
5. **vscode ユーザーが何でも sudo できた（解決済み・2026-10-08）**
   ベースイメージの `/etc/sudoers.d/vscode`（`NOPASSWD:ALL`）が残っていて、コンテナ内からファイアウォールを外せる状態だった。
   → Dockerfile でこのファイルを削除。`sudo -l` で、許可がファイアウォールのスクリプトだけになったことを確認済み。
   コンテナ内で apt install はできなくなったので、パッケージの追加は Dockerfile に書いてリビルドする。

## 未着手・検討中の改善

- **仮想環境の配置**: ワークスペースが Windows 側にあり、`.venv` への書き込み（PySide6）が非常に遅い可能性。
  `containerEnv` に `"UV_PROJECT_ENVIRONMENT": "/home/vscode/.venv"` を追加し、`python.defaultInterpreterPath` も合わせる案。
  根本的には「Clone Repository in Container Volume」でソースごとボリュームへ。
- **ファイアウォール**: rootful Podman 上で `[firewall] OK` まで動くことは確認済み。
  - `statsig.anthropic.com` は名前解決できず許可リストに入らないが、コンテナ内の Claude Code v2.1.293 は起動・ログイン・応答とも問題なし（2026-10-08 確認）
  - VS Code の拡張は、コンテナから直接マーケットプレイスにつながらない（EHOSTUNREACH）が、Windows 側でダウンロードして中継する方式で入っている。今のところ許可リストへの追加は不要
- **Linux / Windows ランナー**: いずれも未構築・未検証。
- **rootless への移行**: 隔離強化のため `claudeVM`（rootless）接続への切替を検討。既存の別 DevContainer（ClaudeCode）への影響確認が必要。
- **Windows ランナーの配置先**: 別PC/VM か開発PCか未確定。

## 作業上の注意（このプロジェクトで Claude Code を使う場合）

- 環境構築・トラブルシュートは **DevContainer の外（ホスト側）** で行う必要がある。
  DevContainer がまだ起動しないこと、また `.claude/settings.json` で `.devcontainer/`・`runner/`・`.github/workflows/` の編集を禁止しているため。
- ホスト側で作業する間は隔離の外なので、権限確認を省略するモードは使わず、`podman` / `wsl` コマンドは一つずつ確認して実行する。
- 環境の作業中だけ、人間が `.claude/settings.json` の該当 deny ルールを外し、完了後に必ず戻す。
- 調査用スクリプト（イベント取り逃がしの再現テスト）は Claude のセッション用の一時フォルダに置いただけで、リポジトリには入れていない。
