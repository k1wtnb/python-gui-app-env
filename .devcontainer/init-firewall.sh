#!/bin/bash
# 開発コンテナの外向き通信を許可リスト方式に制限する。
# Anthropic 公式リファレンス devcontainer の方式（iptables + ipset）を
# Podman / GitHub Actions 連携向けに調整したもの。
set -euo pipefail
IFS=$'\n\t'

ALLOWED_DOMAINS=(
  # Claude Code
  api.anthropic.com
  claude.ai
  platform.claude.com
  console.anthropic.com
  statsig.anthropic.com
  statsig.com
  sentry.io
  # パッケージ
  registry.npmjs.org
  pypi.org
  files.pythonhosted.org
  # VS Code 拡張・サーバー
  marketplace.visualstudio.com
  vscode.blob.core.windows.net
  update.code.visualstudio.com
  # GitHub Actions のログ・アーティファクト取得（gh run view / download）
  objects.githubusercontent.com
  release-assets.githubusercontent.com
  codeload.github.com
  results-receiver.actions.githubusercontent.com
  pipelines.actions.githubusercontent.com
)
for i in $(seq 0 19); do
  ALLOWED_DOMAINS+=("productionresultssa${i}.blob.core.windows.net")
done

echo "[firewall] 既存ルールを初期化"
iptables -F
iptables -X
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
ipset destroy allowed-domains 2>/dev/null || true
ipset create allowed-domains hash:net

echo "[firewall] GitHub の IP レンジを取得"
gh_meta=$(curl -fsS --connect-timeout 10 https://api.github.com/meta)
echo "$gh_meta" | jq -r '(.web + .api + .git)[]' | grep -v ':' | aggregate -q | while read -r cidr; do
  ipset add -exist allowed-domains "$cidr"
done

echo "[firewall] 許可ドメインを名前解決"
for domain in "${ALLOWED_DOMAINS[@]}"; do
  ips=$(dig +short A "$domain" | grep -E '^[0-9]+(\.[0-9]+){3}$' || true)
  if [ -z "$ips" ]; then
    echo "[firewall] WARN: $domain を解決できませんでした（スキップ）"
    continue
  fi
  for ip in $ips; do
    ipset add -exist allowed-domains "$ip"
  done
done

echo "[firewall] ルールを適用"
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A INPUT  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# IPv6 はすべて遮断（ループバックのみ許可）
if command -v ip6tables >/dev/null 2>&1; then
  ip6tables -F || true
  ip6tables -A INPUT  -i lo -j ACCEPT || true
  ip6tables -A OUTPUT -o lo -j ACCEPT || true
  ip6tables -P INPUT DROP || true
  ip6tables -P FORWARD DROP || true
  ip6tables -P OUTPUT DROP || true
fi

echo "[firewall] 動作確認"
if curl -fsS --connect-timeout 5 https://example.com >/dev/null 2>&1; then
  echo "[firewall] NG: example.com に到達できてしまいます"
  exit 1
fi
if ! curl -fsS --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
  echo "[firewall] NG: api.github.com に到達できません"
  exit 1
fi
echo "[firewall] OK: 許可リスト以外への通信は遮断されています"
