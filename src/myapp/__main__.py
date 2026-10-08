import argparse
import sys
from pathlib import Path

from PySide6.QtCore import QTimer
from PySide6.QtWidgets import QApplication

from myapp.main_window import MainWindow


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="myapp")
    parser.add_argument(
        "--smoke-test",
        metavar="PNG",
        type=Path,
        help="起動して画面を PNG に保存したら終了する（CI・パッケージ検証用）",
    )
    args = parser.parse_args(argv)

    app = QApplication(sys.argv[:1])
    window = MainWindow()
    window.show()

    if args.smoke_test:
        def capture() -> None:
            args.smoke_test.parent.mkdir(parents=True, exist_ok=True)
            ok = window.grab().save(str(args.smoke_test))
            app.exit(0 if ok else 1)

        QTimer.singleShot(1500, capture)

    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
