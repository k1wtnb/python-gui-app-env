from PySide6.QtCore import Qt

from myapp.main_window import MainWindow


def _open(qtbot) -> MainWindow:
    window = MainWindow()
    qtbot.addWidget(window)
    window.show()
    qtbot.waitExposed(window)
    return window


def test_initial_state(qtbot, screenshot):
    window = _open(qtbot)
    assert window.message_label.text() == ""
    assert window.name_edit.placeholderText() == "名前を入力"
    screenshot(window, "initial")


def test_greet_with_name(qtbot, screenshot):
    window = _open(qtbot)
    qtbot.keyClicks(window.name_edit, "Claude")
    qtbot.mouseClick(window.greet_button, Qt.MouseButton.LeftButton)
    assert window.message_label.text() == "こんにちは、Claudeさん"
    screenshot(window, "after_greet")


def test_greet_without_name(qtbot, screenshot):
    window = _open(qtbot)
    qtbot.mouseClick(window.greet_button, Qt.MouseButton.LeftButton)
    assert window.message_label.text() == "名前を入力してください"
    screenshot(window, "empty_name")
