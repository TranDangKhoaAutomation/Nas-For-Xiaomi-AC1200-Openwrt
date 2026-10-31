"""Qt 6 setup window for the Windows NAS opener."""
import json
import sys

from PySide6.QtCore import Qt
from PySide6.QtGui import QFont, QIcon, QPixmap
from PySide6.QtWidgets import (
    QApplication, QCheckBox, QDialog, QFrame, QHBoxLayout, QLabel, QLineEdit,
    QMessageBox, QPushButton, QVBoxLayout,
)


def application(icon):
    app = QApplication.instance() or QApplication(sys.argv[:1])
    app.setApplicationName('Khoa NAS')
    app.setOrganizationName('Trần Đăng Khoa Automation')
    app.setFont(QFont('Segoe UI', 10))
    app.setWindowIcon(QIcon(str(icon)))
    return app


def show_error(text, icon):
    app = application(icon)
    QMessageBox.warning(None, 'Khoa NAS', text)


def create_setup(install, install_dir, valid_host, asset, startup_enabled, on_saved=None):
    app = application(asset('khoa-nas.ico'))
    window = QDialog()
    window.setWindowTitle('Khoa NAS · Cài đặt')
    window.setWindowFlag(Qt.WindowType.WindowContextHelpButtonHint, False)
    window.setFixedWidth(500)
    window.setStyleSheet('''
        QDialog { background: #f5f8fa; color: #163a46; }
        QLabel { background: transparent; color: #163a46; }
        QLabel#brand { color: #07898d; font-size: 12px; font-weight: 600; letter-spacing: 1px; }
        QLabel#title { font-size: 24px; font-weight: 600; }
        QLabel#subtitle, QLabel#hint, QLabel#footer { color: #647982; }
        QLabel#subtitle { font-size: 14px; }
        QLabel#cardTitle { font-size: 15px; font-weight: 600; }
        QFrame#card { background: white; border: 1px solid #dbe5e9; border-radius: 12px; }
        QLineEdit { background: #ffffff; color: #163a46; border: 1px solid #b9ced5;
            border-radius: 7px; padding: 9px; font-size: 14px; selection-background-color: #c9edec; }
        QLineEdit:focus { border: 2px solid #07898d; padding: 8px; }
        QLineEdit:read-only { background: #f5f8fa; }
        QCheckBox { color: #163a46; spacing: 9px; padding: 5px 0; font-size: 14px; }
        QLabel#notice { background: #e7f3f1; color: #256f64; border-radius: 8px; padding: 10px; }
        QLabel#notice[error="true"] { background: #fff0ed; color: #9c3829; }
        QPushButton { background: #ffffff; color: #385965; border: 1px solid #cfdee3;
            border-radius: 7px; padding: 9px 18px; font-size: 14px; }
        QPushButton:hover { background: #edf4f6; border-color: #9ebfc9; }
        QPushButton:focus { border: 2px solid #07898d; padding: 8px 17px; }
        QPushButton#primary { background: #07898d; color: white; border-color: #07898d; font-weight: 600; }
        QPushButton#primary:hover { background: #08777b; }
        QPushButton:disabled { color: #90a3ab; background: #eff3f5; border-color: #e1e9ed; }
    ''')
    layout = QVBoxLayout(window)
    layout.setContentsMargins(20, 18, 20, 18)
    layout.setSpacing(14)

    header = QHBoxLayout()
    header.setSpacing(12)
    logo = QLabel()
    logo.setPixmap(QPixmap(str(asset('github-avatar.png'))).scaled(
        56, 56, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation))
    logo.setFixedSize(58, 58)
    logo.setAccessibleName('Logo Trần Đăng Khoa Automation')
    header.addWidget(logo)
    heading = QVBoxLayout()
    heading.setSpacing(5)
    brand = QLabel('KHOA NAS')
    brand.setObjectName('brand')
    title = QLabel('Kết nối NAS')
    title.setObjectName('title')
    heading.addWidget(brand)
    heading.addWidget(title)
    header.addLayout(heading, 1)
    layout.addLayout(header)

    card = QFrame()
    card.setObjectName('card')
    fields = QVBoxLayout(card)
    fields.setContentsMargins(16, 14, 16, 14)
    fields.setSpacing(8)
    card_title = QLabel('Địa chỉ router')
    card_title.setObjectName('cardTitle')
    fields.addWidget(card_title)
    address = QLineEdit()
    address.setAccessibleName('Địa chỉ IP router được phép')
    address.setPlaceholderText('IP LAN hoặc Tailscale của router')
    address.setClearButtonEnabled(True)
    address.setMinimumHeight(40)
    try:
        saved = json.loads((install_dir() / 'allowed-hosts.json').read_text(encoding='utf-8'))
        address.setText(', '.join(valid_host(host) for host in saved))
    except (OSError, ValueError, TypeError):
        pass
    fields.addWidget(address)
    hint = QLabel('IP LAN / Tailscale · Nhiều IP cách nhau bằng dấu phẩy')
    hint.setObjectName('hint')
    hint.setWordWrap(True)
    fields.addWidget(hint)
    layout.addWidget(card)

    startup = QCheckBox('Khởi động cùng Windows')
    startup.setObjectName('startup')
    startup.setChecked(startup_enabled())
    startup.setAccessibleName('Khởi động cùng Windows')
    layout.addWidget(startup)
    startup_hint = QLabel('Chạy nền ở khay hệ thống khi đăng nhập.')
    startup_hint.setObjectName('hint')
    layout.addWidget(startup_hint)

    notice = QLabel()
    notice.setObjectName('notice')
    notice.setWordWrap(True)
    notice.setAccessibleName('Trạng thái thiết lập')
    layout.addWidget(notice)
    notice.hide()

    buttons = QHBoxLayout()
    buttons.setSpacing(10)
    help_button = QPushButton('Trợ giúp')
    help_button.setFlat(True)
    help_button.clicked.connect(lambda: QMessageBox.information(window, 'Kết nối NAS',
        'Lấy IP trong trang Hướng dẫn kết nối của router.\n'
        'Cài một lần, sau đó bấm Mở thư mục NAS trên router.\n'
        'Khởi động cùng Windows: chạy nền, không mở cửa sổ hay tự mở ổ.\n'
        'Mở lại cài đặt từ Start Menu hoặc biểu tượng ở khay hệ thống.\n'
        'Khi truy cập từ xa, giữ Tailscale kết nối.'))
    buttons.addWidget(help_button)
    buttons.addStretch(1)
    cancel = QPushButton('Đóng')
    cancel.clicked.connect(window.reject)
    primary = QPushButton('Lưu thiết lập')
    primary.setObjectName('primary')
    primary.setDefault(True)
    buttons.addWidget(cancel)
    buttons.addWidget(primary)
    layout.addLayout(buttons)
    def submit():
        try:
            install([host.strip() for host in address.text().split(',') if host.strip()], startup.isChecked())
        except Exception as exc:
            notice.show()
            notice.setText(str(exc))
            notice.setProperty('error', True)
            notice.style().unpolish(notice)
            notice.style().polish(notice)
            address.setFocus()
            window.adjustSize()
            return
        notice.setProperty('error', False)
        notice.style().unpolish(notice)
        notice.style().polish(notice)
        notice.setText('Đã lưu. Sẽ chạy nền khi đăng nhập Windows.' if startup.isChecked()
                       else 'Đã lưu. Khởi động cùng Windows đang tắt.')
        notice.show()
        if on_saved:
            on_saved()
        window.adjustSize()

    primary.clicked.connect(submit)
    address.setFocus()
    window.adjustSize()
    return window


def run_setup(install, install_dir, valid_host, asset, startup_enabled=lambda: False):
    window = create_setup(install, install_dir, valid_host, asset, startup_enabled)
    window.exec()
