from pathlib import Path

import pytest


def pytest_addoption(parser):
    parser.addoption(
        "--screenshot-dir",
        default="artifacts/screenshots/local",
        help="テスト中のスクリーンショット保存先",
    )


@pytest.fixture
def screenshot(request, qtbot):
    """screenshot(widget, "名前") で PNG を保存する。Claude はこの画像を見て見た目を確認する。"""
    out_dir = Path(request.config.getoption("--screenshot-dir"))
    out_dir.mkdir(parents=True, exist_ok=True)

    def _take(widget, name: str) -> Path:
        qtbot.wait(100)  # 描画が落ち着くのを待つ
        path = out_dir / f"{request.node.name}__{name}.png"
        assert widget.grab().save(str(path)), f"スクリーンショットの保存に失敗: {path}"
        return path

    return _take
