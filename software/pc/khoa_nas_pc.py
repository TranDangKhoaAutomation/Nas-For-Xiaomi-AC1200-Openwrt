import ctypes
import json
import os
import shutil
import socket
import subprocess
import threading
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox, simpledialog, ttk

APP_NAME = "Khoa NAS"
DEFAULT_HOST = "100.64.0.1"
DEFAULT_SHARES = ("NAS1", "NAS2", "PRIVATE")
CREATE_NO_WINDOW = 0x08000000 if os.name == "nt" else 0


RESOURCETYPE_DISK = 0x00000001
CONNECT_UPDATE_PROFILE = 0x00000001

class NETRESOURCEW(ctypes.Structure):
    _fields_ = [
        ("dwScope", ctypes.c_uint32),
        ("dwType", ctypes.c_uint32),
        ("dwDisplayType", ctypes.c_uint32),
        ("dwUsage", ctypes.c_uint32),
        ("lpLocalName", ctypes.c_wchar_p),
        ("lpRemoteName", ctypes.c_wchar_p),
        ("lpComment", ctypes.c_wchar_p),
        ("lpProvider", ctypes.c_wchar_p),
    ]


_mpr = ctypes.WinDLL("mpr")
_mpr.WNetAddConnection2W.argtypes = [
    ctypes.POINTER(NETRESOURCEW),
    ctypes.c_wchar_p,
    ctypes.c_wchar_p,
    ctypes.c_uint32,
]
_mpr.WNetAddConnection2W.restype = ctypes.c_uint32
_mpr.WNetCancelConnection2W.argtypes = [
    ctypes.c_wchar_p,
    ctypes.c_uint32,
    ctypes.c_bool,
]
_mpr.WNetCancelConnection2W.restype = ctypes.c_uint32


def _wnet_error_message(code: int) -> str:
    known = {
        5: "Windows từ chối quyền truy cập.",
        53: "Không tìm thấy đường dẫn mạng.",
        67: "Không tìm thấy tên share.",
        85: "Ký tự ổ đĩa đã được sử dụng.",
        86: "Sai mật khẩu SMB.",
        1219: "Windows đang có kết nối tới cùng NAS bằng tài khoản khác.",
        1326: "Sai tài khoản hoặc mật khẩu SMB.",
        2250: "Kết nối mạng không tồn tại.",
    }
    detail = known.get(code, "")
    system = ctypes.FormatError(code).strip()
    if detail and system and detail.casefold() not in system.casefold():
        return f"{detail} ({system})"
    return detail or system or f"Lỗi Windows {code}"


def map_network_drive(
    drive: str,
    unc: str,
    username: str,
    password: str,
    *,
    persistent: bool = True,
) -> None:
    nr = NETRESOURCEW()
    nr.dwType = RESOURCETYPE_DISK
    nr.lpLocalName = drive
    nr.lpRemoteName = unc
    flags = CONNECT_UPDATE_PROFILE if persistent else 0
    code = int(
        _mpr.WNetAddConnection2W(
            ctypes.byref(nr),
            password,
            username,
            flags,
        )
    )
    if code:
        raise OSError(code, _wnet_error_message(code))


def unmap_network_drive(
    drive_or_unc: str,
    *,
    persistent: bool = True,
    force: bool = True,
    ignore_missing: bool = True,
) -> None:
    flags = CONNECT_UPDATE_PROFILE if persistent else 0
    code = int(_mpr.WNetCancelConnection2W(drive_or_unc, flags, force))
    if code and not (ignore_missing and code == 2250):
        raise OSError(code, _wnet_error_message(code))


@dataclass
class EntryInfo:
    name: str
    path: str
    is_dir: bool
    size: int
    modified: float


def human_size(value: int) -> str:
    size = float(value)
    units = ("B", "KB", "MB", "GB", "TB")
    unit = 0
    while size >= 1024 and unit < len(units) - 1:
        size /= 1024
        unit += 1
    return f"{size:.0f} {units[unit]}" if unit == 0 else f"{size:.1f} {units[unit]}"


def normalize_unc(value: str) -> str:
    return value.rstrip("\\/").casefold()


def mapped_drives() -> dict[str, str]:
    """Return {drive_letter: UNC provider} for persistent/current network drives."""
    script = (
        "Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=4' | "
        "Select-Object DeviceID,ProviderName | ConvertTo-Json -Compress"
    )
    proc = subprocess.run(
        ["powershell.exe", "-NoProfile", "-Command", script],
        text=True,
        capture_output=True,
        timeout=10,
        creationflags=CREATE_NO_WINDOW,
    )
    if proc.returncode != 0 or not proc.stdout.strip():
        return {}
    data = json.loads(proc.stdout)
    if isinstance(data, dict):
        data = [data]
    result: dict[str, str] = {}
    for item in data:
        drive = str(item.get("DeviceID") or "").upper()
        provider = str(item.get("ProviderName") or "")
        if drive and provider:
            result[drive] = provider
    return result



def tcp_reachable(host: str, port: int = 445, timeout: float = 3.0) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def path_accessible(path: str, timeout: int = 8) -> bool:
    try:
        proc = subprocess.run(
            ["cmd.exe", "/d", "/c", "dir", path],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=timeout,
            creationflags=CREATE_NO_WINDOW,
        )
        return proc.returncode == 0
    except (subprocess.TimeoutExpired, OSError):
        return False

def logical_drive_mask() -> int:
    return int(ctypes.windll.kernel32.GetLogicalDrives())


def choose_free_drive() -> str:
    used = logical_drive_mask()
    for code in range(ord("Z"), ord("D") - 1, -1):
        index = code - ord("A")
        if not (used & (1 << index)):
            return chr(code) + ":"
    raise RuntimeError("Không còn ký tự ổ đĩa trống từ D: đến Z:.")


class NasApp(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title(APP_NAME)
        self.geometry("1120x700")
        self.minsize(860, 540)

        self.connected_unc = ""
        self.connected_root = ""
        self.mapped_drive = ""
        self.current_path = ""
        self.entries: dict[str, EntryInfo] = {}
        self.busy = False
        self._task_seq = 0

        self.host_var = tk.StringVar(value=DEFAULT_HOST)
        self.share_var = tk.StringVar(value=DEFAULT_SHARES[0])
        self.user_var = tk.StringVar()
        self.password_var = tk.StringVar()
        self.status_var = tk.StringVar(value="Chưa kết nối")
        self.path_var = tk.StringVar(value="")
        self.space_var = tk.StringVar(value="")
        self.mapping_var = tk.StringVar(value="Chưa có ổ mạng trong This PC")
        self.progress_var = tk.DoubleVar(value=0)

        self._load_config()
        self._build_ui()
        self.protocol("WM_DELETE_WINDOW", self._on_close)
        self.after(500, self._auto_attach_existing)

    @property
    def config_path(self) -> Path:
        base = Path(os.environ.get("APPDATA", Path.home()))
        return base / "KhoaNAS" / "config.json"

    def _load_config(self) -> None:
        try:
            data = json.loads(self.config_path.read_text(encoding="utf-8"))
        except Exception:
            return
        self.host_var.set(data.get("host", DEFAULT_HOST))
        self.share_var.set(data.get("share", DEFAULT_SHARES[0]))
        self.user_var.set(data.get("user", ""))

    def _save_config(self) -> None:
        try:
            self.config_path.parent.mkdir(parents=True, exist_ok=True)
            self.config_path.write_text(
                json.dumps(
                    {
                        "host": self.host_var.get().strip(),
                        "share": self.share_var.get().strip(),
                        "user": self.user_var.get().strip(),
                    },
                    ensure_ascii=False,
                    indent=2,
                ),
                encoding="utf-8",
            )
        except Exception:
            pass

    def _build_ui(self) -> None:
        top = ttk.LabelFrame(self, text="Kết nối NAS")
        top.pack(fill="x", padx=10, pady=(10, 6))

        ttk.Label(top, text="Tailscale IP / Host").grid(row=0, column=0, sticky="w", padx=6, pady=6)
        ttk.Entry(top, textvariable=self.host_var, width=20).grid(row=1, column=0, padx=6, pady=(0, 8))

        ttk.Label(top, text="Share").grid(row=0, column=1, sticky="w", padx=6, pady=6)
        share_box = ttk.Combobox(
            top,
            textvariable=self.share_var,
            values=DEFAULT_SHARES,
            width=14,
            state="readonly",
        )
        share_box.grid(row=1, column=1, padx=6, pady=(0, 8))
        share_box.bind("<<ComboboxSelected>>", self._share_changed)

        ttk.Label(top, text="Tài khoản SMB").grid(row=0, column=2, sticky="w", padx=6, pady=6)
        ttk.Entry(top, textvariable=self.user_var, width=20).grid(row=1, column=2, padx=6, pady=(0, 8))

        ttk.Label(top, text="Mật khẩu").grid(row=0, column=3, sticky="w", padx=6, pady=6)
        ttk.Entry(top, textvariable=self.password_var, width=24, show="*").grid(row=1, column=3, padx=6, pady=(0, 8))

        self.connect_btn = ttk.Button(top, text="Kết nối + thêm vào This PC", command=self.connect)
        self.connect_btn.grid(row=1, column=4, padx=6, pady=(0, 8))

        self.detach_btn = ttk.Button(top, text="Ngắt trong app", command=self.detach_app, state="disabled")
        self.detach_btn.grid(row=1, column=5, padx=6, pady=(0, 8))

        self.remove_btn = ttk.Button(
            top,
            text="Xóa khỏi This PC",
            command=self.remove_from_this_pc,
            state="disabled",
        )
        self.remove_btn.grid(row=1, column=6, padx=6, pady=(0, 8))

        mapping = ttk.Frame(self)
        mapping.pack(fill="x", padx=10, pady=(0, 4))
        ttk.Label(mapping, text="This PC:").pack(side="left")
        ttk.Label(mapping, textvariable=self.mapping_var).pack(side="left", padx=(6, 0))

        bar = ttk.Frame(self)
        bar.pack(fill="x", padx=10, pady=4)
        ttk.Button(bar, text="↑ Lên", command=self.go_up).pack(side="left")
        ttk.Button(bar, text="Làm mới", command=self.refresh).pack(side="left", padx=(6, 0))
        ttk.Button(bar, text="Tạo thư mục", command=self.create_folder).pack(side="left", padx=(6, 0))
        ttk.Button(bar, text="Đổi tên", command=self.rename_selected).pack(side="left", padx=(6, 0))
        ttk.Button(bar, text="Xóa", command=self.delete_selected).pack(side="left", padx=(6, 0))
        ttk.Button(bar, text="Tải lên", command=self.upload).pack(side="left", padx=(18, 0))
        ttk.Button(bar, text="Tải xuống", command=self.download_selected).pack(side="left", padx=(6, 0))
        ttk.Label(bar, textvariable=self.space_var).pack(side="right")

        path_frame = ttk.Frame(self)
        path_frame.pack(fill="x", padx=10, pady=(2, 5))
        ttk.Label(path_frame, text="Đường dẫn:").pack(side="left")
        ttk.Label(path_frame, textvariable=self.path_var).pack(side="left", padx=(6, 0))

        columns = ("type", "size", "modified")
        self.tree = ttk.Treeview(self, columns=columns, show="tree headings", selectmode="browse")
        self.tree.heading("#0", text="Tên")
        self.tree.heading("type", text="Loại")
        self.tree.heading("size", text="Kích thước")
        self.tree.heading("modified", text="Sửa đổi")
        self.tree.column("#0", width=520, minwidth=220)
        self.tree.column("type", width=100, anchor="center")
        self.tree.column("size", width=120, anchor="e")
        self.tree.column("modified", width=180, anchor="center")
        self.tree.pack(fill="both", expand=True, padx=10, pady=4)
        self.tree.bind("<Double-1>", self._open_selected)

        bottom = ttk.Frame(self)
        bottom.pack(fill="x", padx=10, pady=(3, 10))
        self.progress = ttk.Progressbar(bottom, variable=self.progress_var, maximum=100)
        self.progress.pack(fill="x", expand=True, side="left")
        ttk.Label(bottom, textvariable=self.status_var, width=44, anchor="e").pack(side="right", padx=(10, 0))

    def _set_busy(self, value: bool, status: str | None = None) -> None:
        self.busy = value
        self._update_buttons()
        if status is not None:
            self.status_var.set(status)

    def _update_buttons(self) -> None:
        self.connect_btn.configure(
            state="disabled" if self.busy or self.connected_root else "normal"
        )
        self.detach_btn.configure(
            state="normal" if self.connected_root and not self.busy else "disabled"
        )
        self.remove_btn.configure(
            state="normal" if self.mapped_drive and not self.busy else "disabled"
        )

    def _run_bg(
        self,
        fn,
        done=None,
        *,
        status: str = "Đang xử lý...",
        timeout_seconds: int = 30,
    ) -> None:
        if self.busy:
            return

        self._task_seq += 1
        task_id = self._task_seq
        self._set_busy(True, status)

        def expire() -> None:
            if task_id != self._task_seq or not self.busy:
                return
            self._task_seq += 1
            self.progress_var.set(0)
            self._set_busy(False, "Hết thời gian chờ")
            messagebox.showerror(
                APP_NAME,
                f"Tác vụ không phản hồi sau {timeout_seconds} giây.\n"
                "App đã tự mở khóa để bạn có thể thử lại.",
                parent=self,
            )

        timer_id = self.after(max(1000, timeout_seconds * 1000), expire)

        def finish_error(exc: Exception) -> None:
            if task_id != self._task_seq:
                return
            try:
                self.after_cancel(timer_id)
            except tk.TclError:
                pass
            self._task_seq += 1
            self.progress_var.set(0)
            self._set_busy(False, "Lỗi")
            messagebox.showerror(APP_NAME, str(exc), parent=self)

        def finish_ok(result) -> None:
            if task_id != self._task_seq:
                return
            try:
                self.after_cancel(timer_id)
            except tk.TclError:
                pass
            self._task_seq += 1
            self.progress_var.set(0)
            self._set_busy(False, "Sẵn sàng")
            if done:
                done(result)

        def worker() -> None:
            try:
                result = fn()
            except Exception as exc:
                self.after(0, lambda exc=exc: finish_error(exc))
                return
            self.after(0, lambda result=result: finish_ok(result))

        threading.Thread(target=worker, daemon=True).start()

    def _unc(self) -> str:
        host = self.host_var.get().strip()
        share = self.share_var.get().strip()
        if not host or not share:
            raise ValueError("Thiếu Host hoặc Share.")
        return rf"\\{host}\{share}"

    def _find_mapping(self, unc: str) -> str:
        target = normalize_unc(unc)
        for drive, provider in mapped_drives().items():
            if normalize_unc(provider) == target:
                return drive
        return ""

    def _share_changed(self, _event=None) -> None:
        if self.busy:
            return
        self.detach_app()
        self.after(100, self._auto_attach_existing)

    def _auto_attach_existing(self) -> None:
        if self.busy:
            return
        try:
            unc = self._unc()
            drive = self._find_mapping(unc)
        except Exception:
            return
        if drive:
            root = drive + "\\"
            if path_accessible(root, timeout=5):
                self._attach_mapping(unc, drive, auto=True)
                return
        self.mapping_var.set("Chưa map share này vào This PC")
        self.mapped_drive = ""
        self._update_buttons()

    def connect(self) -> None:
        def work():
            unc = self._unc()
            existing = self._find_mapping(unc)
            if existing and path_accessible(existing + "\\", timeout=5):
                return unc, existing, False

            host = self.host_var.get().strip()
            if not tcp_reachable(host, 445, timeout=3.0):
                raise TimeoutError(
                    f"Không kết nối được SMB tới {host}:445. "
                    "Hãy kiểm tra Tailscale/NAS rồi thử lại."
                )

            user = self.user_var.get().strip()
            password = self.password_var.get()
            if not user or not password:
                raise ValueError(
                    "Share chưa có trong This PC. Hãy nhập tài khoản SMB và mật khẩu để đăng nhập."
                )

            drive = choose_free_drive()
            try:
                map_network_drive(
                    drive,
                    unc,
                    user,
                    password,
                    persistent=True,
                )
            except OSError as exc:
                code = getattr(exc, "errno", None)
                if code == 1219:
                    raise RuntimeError(
                        "Windows đang giữ một phiên SMB tới NAS bằng credential khác. "
                        "Hãy đóng các cửa sổ Explorer đang mở NAS rồi thử lại."
                    ) from exc
                if code in (86, 1326):
                    raise RuntimeError(
                        "Sai tài khoản hoặc mật khẩu SMB. "
                        "Tài khoản NAS hiện tại là 'nas'."
                    ) from exc
                raise RuntimeError(
                    f"Không thêm được NAS vào This PC. "
                    f"Mã lỗi Windows: {code}. {exc.strerror or exc}"
                ) from exc

            if not path_accessible(drive + "\\", timeout=8):
                try:
                    unmap_network_drive(drive, persistent=True, force=True)
                except OSError:
                    pass
                raise RuntimeError(
                    "Đã tạo ổ mạng nhưng không đọc được dữ liệu NAS trong thời gian cho phép."
                )
            return unc, drive, True

        def done(result):
            unc, drive, created = result
            self.password_var.set("")
            self._save_config()
            self._attach_mapping(unc, drive, auto=not created)

        self._run_bg(
            work,
            done,
            status="Đang xác thực SMB và thêm vào This PC...",
            timeout_seconds=30,
        )

    def _attach_mapping(self, unc: str, drive: str, auto: bool) -> None:
        self.connected_unc = unc
        self.mapped_drive = drive
        self.connected_root = drive + "\\"
        self.current_path = self.connected_root
        self.mapping_var.set(f"{drive} → {unc}  (hiển thị trong This PC)")
        self.status_var.set(
            "Đã tự khôi phục mapping cũ" if auto else "Đã thêm NAS vào This PC"
        )
        self._update_buttons()
        self.refresh()

    def detach_app(self) -> None:
        """Detach UI only. The Windows persistent network drive remains in This PC."""
        self.connected_unc = ""
        self.connected_root = ""
        self.current_path = ""
        self.entries.clear()
        for item in self.tree.get_children():
            self.tree.delete(item)
        self.path_var.set("")
        self.space_var.set("")
        self.status_var.set("Đã ngắt trong app; ổ mạng vẫn còn trong This PC")
        self._update_buttons()

    def remove_from_this_pc(self) -> None:
        if not self.mapped_drive:
            return
        drive = self.mapped_drive
        unc = self.connected_unc or self._unc()
        if not messagebox.askyesno(
            APP_NAME,
            f"Xóa {drive} → {unc} khỏi This PC?\n\n"
            "Lần sau bạn sẽ phải đăng nhập lại để thêm ổ mạng.",
            parent=self,
        ):
            return

        def work():
            try:
                unmap_network_drive(
                    drive,
                    persistent=True,
                    force=True,
                    ignore_missing=True,
                )
            except OSError as exc:
                code = getattr(exc, "errno", None)
                raise RuntimeError(
                    f"Không xóa được ổ mạng khỏi This PC. "
                    f"Mã lỗi Windows: {code}. {exc.strerror or exc}"
                ) from exc
            return drive

        def done(_):
            self.connected_unc = ""
            self.connected_root = ""
            self.mapped_drive = ""
            self.current_path = ""
            self.entries.clear()
            for item in self.tree.get_children():
                self.tree.delete(item)
            self.path_var.set("")
            self.space_var.set("")
            self.password_var.set("")
            self.mapping_var.set("Đã xóa khỏi This PC — lần sau phải đăng nhập lại")
            self.status_var.set("Đã xóa mapping")
            self._update_buttons()

        self._run_bg(
            work,
            done,
            status="Đang xóa ổ mạng khỏi This PC...",
            timeout_seconds=20,
        )

    def refresh(self) -> None:
        if not self.current_path:
            return

        def work():
            result: list[EntryInfo] = []
            with os.scandir(self.current_path) as it:
                for entry in it:
                    try:
                        st = entry.stat(follow_symlinks=False)
                        is_dir = entry.is_dir(follow_symlinks=False)
                        result.append(
                            EntryInfo(
                                name=entry.name,
                                path=entry.path,
                                is_dir=is_dir,
                                size=0 if is_dir else st.st_size,
                                modified=st.st_mtime,
                            )
                        )
                    except OSError:
                        continue
            result.sort(key=lambda x: (not x.is_dir, x.name.casefold()))
            try:
                usage = shutil.disk_usage(self.connected_root)
            except OSError:
                usage = None
            return result, usage

        def done(data):
            rows, usage = data
            self.entries.clear()
            for item in self.tree.get_children():
                self.tree.delete(item)
            for row in rows:
                iid = self.tree.insert(
                    "",
                    "end",
                    text=row.name,
                    values=(
                        "Thư mục" if row.is_dir else "File",
                        "" if row.is_dir else human_size(row.size),
                        datetime.fromtimestamp(row.modified).strftime("%Y-%m-%d %H:%M:%S"),
                    ),
                )
                self.entries[iid] = row
            self.path_var.set(self.current_path)
            if usage:
                self.space_var.set(f"{human_size(usage.free)} trống / {human_size(usage.total)}")
            else:
                self.space_var.set("")

        self._run_bg(
            work,
            done,
            status="Đang tải danh sách file...",
            timeout_seconds=20,
        )

    def _selected(self) -> EntryInfo | None:
        selection = self.tree.selection()
        if not selection:
            return None
        return self.entries.get(selection[0])

    def _open_selected(self, _event=None) -> None:
        item = self._selected()
        if not item:
            return
        if item.is_dir:
            self.current_path = item.path
            self.refresh()
        else:
            try:
                os.startfile(item.path)
            except OSError as exc:
                messagebox.showerror(APP_NAME, str(exc), parent=self)

    def go_up(self) -> None:
        if not self.current_path or self.current_path == self.connected_root:
            return
        parent = os.path.dirname(self.current_path.rstrip("\\/"))
        if parent.casefold().startswith(self.connected_root.rstrip("\\").casefold()):
            self.current_path = parent
        else:
            self.current_path = self.connected_root
        self.refresh()

    def create_folder(self) -> None:
        if not self.current_path:
            return
        name = simpledialog.askstring(APP_NAME, "Tên thư mục mới:", parent=self)
        if not name or not name.strip():
            return
        target = os.path.join(self.current_path, name.strip())
        self._run_bg(lambda: os.mkdir(target), lambda _: self.refresh())

    def rename_selected(self) -> None:
        item = self._selected()
        if not item:
            return
        name = simpledialog.askstring(APP_NAME, "Tên mới:", initialvalue=item.name, parent=self)
        if not name or name == item.name:
            return
        target = os.path.join(os.path.dirname(item.path), name)
        self._run_bg(lambda: os.rename(item.path, target), lambda _: self.refresh())

    def delete_selected(self) -> None:
        item = self._selected()
        if not item:
            return
        text = f'Xóa {"thư mục rỗng" if item.is_dir else "file"} "{item.name}"?'
        if not messagebox.askyesno(APP_NAME, text, parent=self):
            return
        def work():
            if item.is_dir:
                os.rmdir(item.path)
            else:
                os.remove(item.path)
        self._run_bg(work, lambda _: self.refresh())

    def _copy_with_progress(self, source: str, target: str) -> None:
        total = os.path.getsize(source)
        copied = 0
        Path(target).parent.mkdir(parents=True, exist_ok=True)
        with open(source, "rb") as src, open(target, "wb") as dst:
            while True:
                chunk = src.read(1024 * 1024)
                if not chunk:
                    break
                dst.write(chunk)
                copied += len(chunk)
                percent = 100 if total == 0 else copied * 100 / total
                self.after(0, lambda p=percent: self.progress_var.set(p))
        try:
            shutil.copystat(source, target)
        except OSError:
            pass

    def upload(self) -> None:
        if not self.current_path:
            return
        source = filedialog.askopenfilename(parent=self, title="Chọn file tải lên")
        if not source:
            return
        target = os.path.join(self.current_path, os.path.basename(source))
        if os.path.exists(target) and not messagebox.askyesno(
            APP_NAME, "File đã tồn tại. Ghi đè?", parent=self
        ):
            return
        temp = target + ".uploading"

        def work():
            try:
                if os.path.exists(temp):
                    os.remove(temp)
                self._copy_with_progress(source, temp)
                if os.path.exists(target):
                    os.remove(target)
                os.replace(temp, target)
            except Exception:
                try:
                    if os.path.exists(temp):
                        os.remove(temp)
                except OSError:
                    pass
                raise

        self._run_bg(work, lambda _: self.refresh())

    def download_selected(self) -> None:
        item = self._selected()
        if not item or item.is_dir:
            return
        target = filedialog.asksaveasfilename(
            parent=self, title="Lưu file", initialfile=item.name
        )
        if not target:
            return
        temp = target + ".part"

        def work():
            try:
                if os.path.exists(temp):
                    os.remove(temp)
                self._copy_with_progress(item.path, temp)
                if os.path.exists(target):
                    os.remove(target)
                os.replace(temp, target)
            except Exception:
                try:
                    if os.path.exists(temp):
                        os.remove(temp)
                except OSError:
                    pass
                raise

        self._run_bg(
            work,
            lambda _: messagebox.showinfo(APP_NAME, f"Đã tải:\n{target}", parent=self),
        )

    def _on_close(self) -> None:
        self._save_config()
        self.destroy()


if __name__ == "__main__":
    NasApp().mainloop()
