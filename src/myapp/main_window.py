from PySide6.QtWidgets import (
    QLabel,
    QLineEdit,
    QMainWindow,
    QPushButton,
    QVBoxLayout,
    QWidget,
)


class MainWindow(QMainWindow):
    """サンプル画面。テストからは objectName / 属性で各部品にアクセスする。"""

    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("MyApp")
        self.resize(480, 240)

        central = QWidget(self)
        layout = QVBoxLayout(central)

        self.name_edit = QLineEdit()
        self.name_edit.setObjectName("nameEdit")
        self.name_edit.setPlaceholderText("名前を入力")

        self.greet_button = QPushButton("挨拶する")
        self.greet_button.setObjectName("greetButton")

        self.message_label = QLabel("")
        self.message_label.setObjectName("messageLabel")

        layout.addWidget(self.name_edit)
        layout.addWidget(self.greet_button)
        layout.addWidget(self.message_label)
        layout.addStretch(1)
        self.setCentralWidget(central)

        self.greet_button.clicked.connect(self._on_greet)

    def _on_greet(self) -> None:
        name = self.name_edit.text().strip()
        if name:
            self.message_label.setText(f"こんにちは、{name}さん")
        else:
            self.message_label.setText("名前を入力してください")
