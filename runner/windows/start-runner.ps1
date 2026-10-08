<#
  Windows 検証ランナーの起動ループ
  - 必ず「ログオン中のユーザーセッション」で実行すること（サービス化しない）
    → サービスとして動かすとデスクトップが無く GUI テストが失敗する
  - 管理者権限のない専用ユーザーで、自動ログオン + タスクスケジューラ（ログオン時）で起動推奨
  - 事前に Python 3.12 / Git / GitHub CLI をインストールし、gh auth login 済みであること
  使い方:
    .\runner\windows\start-runner.ps1 -Repo "OWNER/REPO"
#>
param(
  [Parameter(Mandatory = $true)][string]$Repo,
  [string]$RunnerDir = (Join-Path $env:USERPROFILE "gh-runner")
)

if (-not (Test-Path (Join-Path $RunnerDir "run.cmd"))) {
  New-Item -ItemType Directory -Force -Path $RunnerDir | Out-Null
  $tag = gh api repos/actions/runner/releases/latest --jq ".tag_name"
  $ver = $tag.TrimStart("v")
  $zip = Join-Path $env:TEMP "actions-runner-win-x64-$ver.zip"
  Invoke-WebRequest "https://github.com/actions/runner/releases/download/$tag/actions-runner-win-x64-$ver.zip" -OutFile $zip
  Expand-Archive -Path $zip -DestinationPath $RunnerDir -Force
  Remove-Item $zip
}

while ($true) {
  # 前回ジョブの作業ディレクトリを毎回削除（使い捨てに近づける）
  $work = Join-Path $RunnerDir "_work"
  if (Test-Path $work) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }

  $name = "gui-runner-win-" + $env:COMPUTERNAME + "-" + (Get-Date -Format "yyyyMMddHHmmss")
  $jit = gh api -X POST "repos/$Repo/actions/runners/generate-jitconfig" `
    -f "name=$name" -F runner_group_id=1 `
    -f "labels[]=self-hosted" -f "labels[]=windows" -f "labels[]=x64" -f "labels[]=gui-test" `
    -f "work_folder=_work" --jq ".encoded_jit_config"

  if ($LASTEXITCODE -ne 0 -or -not $jit) {
    Write-Warning "JIT 設定の取得に失敗しました。30秒後に再試行します。"
    Start-Sleep -Seconds 30
    continue
  }

  Write-Host "[$(Get-Date -Format T)] ランナー $name を起動（ジョブ待機中）"
  & (Join-Path $RunnerDir "run.cmd") --jitconfig $jit
  Write-Host "[$(Get-Date -Format T)] ランナー $name 終了"
  Start-Sleep -Seconds 2
}
