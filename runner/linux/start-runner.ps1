<#
  Linux 検証ランナーの起動ループ（Windows ホストの PowerShell で実行）
  - ジョブ1件ごとに新しいコンテナを作り、終わったら破棄する
  - ランナー登録用の権限（Administration）は、このホスト側の gh だけが持つ
  使い方:
    podman build -t gui-runner-linux:latest runner/linux
    .\runner\linux\start-runner.ps1 -Repo "OWNER/REPO"
#>
param(
  [Parameter(Mandatory = $true)][string]$Repo,
  [string]$Image = "localhost/gui-runner-linux:latest"
)

while ($true) {
  $name = "gui-runner-linux-" + (Get-Date -Format "yyyyMMddHHmmss")
  $jit = gh api -X POST "repos/$Repo/actions/runners/generate-jitconfig" `
    -f "name=$name" -F runner_group_id=1 `
    -f "labels[]=self-hosted" -f "labels[]=linux" -f "labels[]=x64" -f "labels[]=gui-test" `
    -f "work_folder=_work" --jq ".encoded_jit_config"

  if ($LASTEXITCODE -ne 0 -or -not $jit) {
    Write-Warning "JIT 設定の取得に失敗しました。30秒後に再試行します。"
    Start-Sleep -Seconds 30
    continue
  }

  Write-Host "[$(Get-Date -Format T)] ランナー $name を起動（ジョブ待機中）"
  # ポイント: Podman のソケットはマウントしない / 権限は全て落とす
  podman run --rm --name $name `
    --cap-drop=ALL `
    --security-opt=no-new-privileges `
    -e "RUNNER_JITCONFIG=$jit" `
    $Image

  Write-Host "[$(Get-Date -Format T)] ランナー $name 終了"
  Start-Sleep -Seconds 2
}
