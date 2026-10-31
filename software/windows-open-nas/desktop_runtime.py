"""One per-user settings/tray process; local IPC never accepts executable paths."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

from PySide6.QtCore import QLockFile, QTimer
from PySide6.QtNetwork import QLocalServer, QLocalSocket
from PySide6.QtGui import QIcon
from PySide6.QtWidgets import QMenu, QSystemTrayIcon

import open_nas as backend
from setup_ui import application, create_setup, show_error


def server_name():
    key = str(backend.install_dir().resolve()).casefold().encode('utf-8')
    return 'KhoaNAS-Open-' + hashlib.sha256(key).hexdigest()[:24]


def relay(message, timeout=700):
    client = QLocalSocket()
    client.connectToServer(server_name())
    if not client.waitForConnected(timeout):
        return None
    data = json.dumps(message).encode('utf-8') + b'\n'
    client.write(data)
    client.flush()
    if client.bytesAvailable() == 0:
        client.waitForReadyRead(timeout)
    reply = bytes(client.readAll())
    client.disconnectFromServer()
    try:
        return json.loads(reply)
    except (ValueError, UnicodeError):
        return {'ok': False}


def relocate(link, background):
    """Downloaded builds hand over to the stable installation, including updates."""
    if not getattr(sys, 'frozen', False):
        return False
    target = backend.install_dir() / 'KhoaNAS-Open.exe'
    source = Path(sys.executable)
    if source.resolve() == target.resolve():
        return False
    changed = not target.is_file() or hashlib.sha256(source.read_bytes()).digest() != hashlib.sha256(target.read_bytes()).digest()
    if changed:
        response = relay({'action': 'quit-for-update'})
        if response is not None and not response.get('ok'):
            raise ValueError('Đóng cửa sổ cài đặt Khoa NAS rồi chạy lại bản cập nhật.')
        if response:
            time.sleep(0.6)
        backend.copy_installed_files()
    hosts = backend.load_hosts()
    if hosts and changed:
        # Preserve the existing startup choice. Only saving the checkbox changes it.
        backend.install(hosts)
    else:
        backend.register_shortcut()
    args = ['--background'] if background else [link] if link else ['--settings']
    subprocess.Popen([str(target), *args], creationflags=subprocess.CREATE_NO_WINDOW)
    return True


class DesktopRuntime:
    def __init__(self, app):
        self.app = app
        self.window = None
        self.tray = None
        self.menu = None
        self.clients = set()
        backend.install_dir().mkdir(parents=True, exist_ok=True)
        self.lock = QLockFile(str(backend.install_dir() / 'desktop.lock'))
        self.lock.setStaleLockTime(0)
        self.server = QLocalServer()
        self.server.setSocketOptions(QLocalServer.SocketOption.UserAccessOption)
        self.server.newConnection.connect(self.accept)
        self.app.aboutToQuit.connect(self.cleanup)

    def start(self):
        return self.lock.tryLock(0) and self.server.listen(server_name())

    def cleanup(self):
        if self.tray:
            self.tray.hide()
        self.server.close()
        self.lock.unlock()

    def settings(self):
        if self.window is not None and self.window.isVisible():
            self.window.showNormal()
            self.window.raise_()
            self.window.activateWindow()
            return
        self.window = create_setup(backend.install, backend.install_dir, backend.valid_host,
                                   backend.asset, backend.startup_enabled, self.update_tray)
        self.window.finished.connect(self.closed)
        self.window.show()
        self.window.raise_()
        self.window.activateWindow()

    def closed(self, _result):
        if not backend.startup_enabled() or self.tray is None or not self.tray.isVisible():
            self.app.quit()

    def update_tray(self):
        enabled = backend.startup_enabled()
        if not enabled:
            if self.tray:
                self.tray.hide()
            return
        if not QSystemTrayIcon.isSystemTrayAvailable():
            return
        if self.tray is None:
            self.tray = QSystemTrayIcon(QIcon(str(backend.asset('khoa-nas.ico'))), self.app)
            self.tray.setToolTip('Khoa NAS · Mở nhanh NAS')
            self.tray.activated.connect(lambda reason: self.settings() if reason == QSystemTrayIcon.ActivationReason.DoubleClick else None)
        self.menu = QMenu()
        self.menu.addAction('Cài đặt…', self.settings)
        hosts = backend.load_hosts()
        if hosts:
            self.menu.addSeparator()
            for host in hosts:
                self.menu.addAction('Mở NAS · ' + host, lambda checked=False, h=host: os.startfile('\\\\' + h, 'explore'))
        self.menu.addSeparator()
        self.menu.addAction('Thoát', self.app.quit)
        self.tray.setContextMenu(self.menu)
        self.tray.show()

    def accept(self):
        while self.server.hasPendingConnections():
            client = self.server.nextPendingConnection()
            client.setReadBufferSize(4097)
            client._buffer = bytearray()
            self.clients.add(client)
            client.readyRead.connect(lambda c=client: self.read(c))
            client.disconnected.connect(lambda c=client: self.release(c))
            client._timeout = QTimer(client)
            client._timeout.setSingleShot(True)
            client._timeout.timeout.connect(client.abort)
            client._timeout.start(2500)
            if client.bytesAvailable():
                self.read(client)

    def release(self, client):
        self.clients.discard(client)
        client.deleteLater()

    def read(self, client):
        client._buffer.extend(bytes(client.readAll()))
        if len(client._buffer) > 4096:
            client.abort()
            return
        if b'\n' not in client._buffer:
            return
        ok = False
        try:
            message = json.loads(bytes(client._buffer).decode('utf-8'))
            if not isinstance(message, dict) or set(message) - {'action', 'link'}:
                raise ValueError('invalid request')
            action = message.get('action')
            if action == 'settings':
                self.settings()
                ok = True
            elif action == 'background':
                ok = True
            elif action == 'open' and isinstance(message.get('link'), str):
                backend.open_link(message['link'])
                ok = True
            elif action == 'quit-for-update' and not (self.window and self.window.isVisible()):
                ok = True
                QTimer.singleShot(150, self.app.quit)
        except (ValueError, OSError, TypeError):
            # Never display or execute untrusted IPC fields as a command.
            pass
        client.write(json.dumps({'ok': ok}).encode() + b'\n')
        client.flush()
        client.disconnectFromServer()


def run(link=None, background=False):
    app = application(backend.asset('khoa-nas.ico'))
    app.setApplicationVersion(backend.APP_VERSION)
    app.setQuitOnLastWindowClosed(False)
    try:
        if background and not backend.startup_enabled():
            return 0
        if relocate(link, background):
            return 0
        request = {'action': 'open', 'link': link} if link else {'action': 'background' if background else 'settings'}
        if link:
            # Validate before forwarding. Receiver also repeats allowlist validation.
            host, _unc = backend.parse_link(link)
            if host not in backend.load_hosts():
                raise ValueError('IP này chưa được cho phép. Mở Khoa NAS để cập nhật IP router.')
        response = relay(request, timeout=250)
        if response is not None:
            if not response.get('ok'):
                raise ValueError('Khoa NAS chưa hoàn tất thao tác. Hãy thử lại.')
            return 0
        runtime = DesktopRuntime(app)
        if not runtime.start():
            response = relay(request, timeout=1200)
            if response and response.get('ok'):
                return 0
            raise ValueError('Khoa NAS đang khởi động. Hãy mở lại sau giây lát.')
        runtime.update_tray()
        if link:
            backend.open_link(link)
            if not backend.startup_enabled():
                runtime.cleanup()
                return 0
        elif not background:
            runtime.settings()
        if background and (not runtime.tray or not runtime.tray.isVisible()):
            runtime.cleanup()
            return 0
        return app.exec()
    except Exception as exc:
        if not background:
            show_error(str(exc), backend.asset('khoa-nas.ico'))
        return 1
