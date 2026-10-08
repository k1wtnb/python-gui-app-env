# セットアップ手順

## 全体構成

```
[開発PC / Windows + Podman Desktop (WSL2)]
  ├─ DevContainer（Claude Code）……外向き通信は許可リストのみ
  │     └─ push / gh run watch / gh run download ──▶ GitHub
  └─ Linux 検証ランナー（Podman コンテナ・1ジョブごとに使い捨て）◀── GitHub Actions

[Windows 検証環境]（ログオン中のデスクトップセッション）
  └─ Windows 検証ランナー ◀── GitHub Actions
```

DevContainer と Linux ランナーは同じ Podman machine 上の **別コンテナ** で、互いに直接は通信しません。
連携はすべて GitHub 経由です。

## 1. GitHub の準備

1. **プライベート** リポジトリを作成する（公開リポジトリでセルフホストランナーは使わない）。
2. トークンを 2 種類用意する（どちらも Fine-grained PAT、対象はこのリポジトリのみ）。

| 用途 | 置き場所 | 権限 |
|---|---|---|
| A: Claude 用 | DevContainer 内の gh | Contents: RW / Actions: RW / Metadata: R |
| B: ランナー登録用 | 各ホストの gh（コンテナの外） | Administration: RW / Metadata: R |

トークン A には **Workflows 権限を付けない** こと。これにより Claude は
`.github/workflows/` を変更したコミットを push できず、ランナーで動く処理の枠組みを書き換えられません。
ワークフローの変更は、あなた自身がホスト側の認証情報で push してください。

3. 最初のコミット（このファイル一式＋ `uv.lock`）はホスト側から push する。
   `uv.lock` は手順4の DevContainer 起動後に生成されるので、その後でコミットしてください。

## 2. Linux 検証ランナー（開発PC）

PowerShell で、このディレクトリをカレントにして実行します。

```powershell
gh auth login                      # トークン B でログイン
podman build -t gui-runner-linux:latest runner/linux
.\runner\linux\start-runner.ps1 -Repo "OWNER/REPO"
```

常駐させる場合は、タスクスケジューラで「ログオン時」にこのスクリプトを実行するよう登録します。
ランナーのイメージを更新したい（actions/runner の新版など）ときは `podman build` をやり直してください。

> 重要: ランナーのコンテナに Podman のソケットをマウントしたり `--privileged` を付けたりしないこと。
> ジョブからホスト側の Podman を操作できるようになり、隔離が無意味になります。

## 3. Windows 検証ランナー

開発PCとは別の Windows 環境（専用PC・VM）を推奨します。開発PCのホストで直接動かすと、
テストコードがあなたの Windows 環境で直接実行されることになるためです。

1. 管理者権限のない専用ユーザーを作成し、自動ログオンを設定する。
2. Git、GitHub CLI、uv をインストールする（`winget install astral-sh.uv`）。
   Python は uv が `.python-version` に従って自動で用意するので、別途インストールは不要です。
3. その専用ユーザーで `gh auth login`（トークン B）。
4. タスクスケジューラで「ログオン時」に以下を実行するよう登録する。

```powershell
powershell -ExecutionPolicy Bypass -File <このリポジトリ>\runner\windows\start-runner.ps1 -Repo "OWNER/REPO"
```

ランナーを Windows サービスとして登録しないでください（デスクトップが無く GUI テストが失敗します）。

## 4. DevContainer（開発PC）

1. VS Code の設定で `"dev.containers.dockerPath": "podman"` になっていることを確認。
2. このディレクトリを開き「Reopen in Container」。初回は依存のインストール後にファイアウォールが有効になります。
   ログ末尾に `[firewall] OK` が出れば成功です。
   初回は `uv sync` で `uv.lock` が生成されます。これをコミットしてください
   （CI は `uv sync --locked` で、ロックファイルと一致しない場合は失敗します）。
3. コンテナ内のターミナルで認証:

```bash
gh auth login --with-token < /dev/stdin   # トークン A を貼り付けて Ctrl+D
gh auth setup-git
git config --global user.name  "あなたの名前"
git config --global user.email "you@example.com"
claude                                     # 初回はログイン
```

認証情報は名前付きボリュームに保存されるので、コンテナを作り直しても残ります。

## 5. 動作確認

```bash
scripts/local-gui-check.sh                 # artifacts/screenshots/local に PNG が出ればOK
curl -m 5 https://example.com              # 失敗すればファイアウォールは正常
```

その後、適当な変更を commit → push し、GitHub の Actions 画面で
`gui-test (linux)` と `gui-test (windows)` が両方緑になることを確認します。

## 6. Claude に任せる

`CLAUDE.md` に開発ループ（ローカル確認 → push → 両 OS の結果取得 → スクショ確認）を書いてあります。
例えば次のように依頼します。

```
設定画面を追加して。ローカルと CI の両方でスクショを確認して、
Windows と Linux で見た目に差があれば報告して。
```

## カスタマイズ

- アプリ名 `myapp` は `pyproject.toml`、`src/myapp/`、ワークフロー内の `--name myapp` / `dist/myapp` をまとめて置換してください。
- 許可する通信先を増やす場合は `.devcontainer/init-firewall.sh` の `ALLOWED_DOMAINS` に追記してコンテナを再起動します。
