# 開発用コンテナ（Claude Code をこの中に閉じ込める）
FROM mcr.microsoft.com/devcontainers/python:1-3.12-bookworm

ENV DEBIAN_FRONTEND=noninteractive
# ベースイメージに含まれる Yarn の apt リポジトリは署名鍵の不整合で apt-get update を失敗させるため削除
# （Node / Yarn は devcontainer feature 側で導入される）
RUN rm -f /etc/apt/sources.list.d/yarn.list /etc/apt/sources.list.d/yarn*.list
RUN apt-get update && apt-get install -y --no-install-recommends \
      # ファイアウォール
      iptables ipset iproute2 dnsutils aggregate jq curl sudo \
      # 仮想ディスプレイと GUI 操作・スクリーンショット
      xvfb xauth x11-utils xdotool imagemagick \
      # PySide6 (Qt6) の実行に必要なライブラリ
      libgl1 libegl1 libxkbcommon0 libxkbcommon-x11-0 libfontconfig1 libdbus-1-3 \
      libxcb-cursor0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-randr0 \
      libxcb-render-util0 libxcb-shape0 libxcb-xinerama0 libxcb-xfixes0 libxcb-xkb1 \
      libglib2.0-0 binutils \
      # 日本語表示用フォント（スクショで文字化けしないように）
      fonts-noto-cjk \
    && rm -rf /var/lib/apt/lists/*

# uv（公式イメージからバイナリをコピー。再現性を重視するならタグを固定する）
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# ファイアウォール初期化スクリプト（vscode ユーザーはこのスクリプトだけ sudo 可）
# claude-code feature が /usr/local/bin/init-firewall.sh を自前の版で上書きするため、別名で置く
COPY init-firewall.sh /usr/local/bin/gui-app-firewall.sh
# ベースイメージの「vscode は何でも sudo 可」（/etc/sudoers.d/vscode）を削除する
RUN chmod 755 /usr/local/bin/gui-app-firewall.sh \
 && rm -f /etc/sudoers.d/vscode \
 && echo "vscode ALL=(root) NOPASSWD: /usr/local/bin/gui-app-firewall.sh" > /etc/sudoers.d/vscode-firewall \
 && chmod 0440 /etc/sudoers.d/vscode-firewall \
 && mkdir -p /home/vscode/.claude /home/vscode/.config/gh \
 && chown -R vscode:vscode /home/vscode/.claude /home/vscode/.config
