# Khoa NAS PC

Python/Tkinter app dùng Windows WNet API để map SMB vào This PC.

Không lưu SMB password plaintext trong source/config.

Build:

~~~powershell
pip install pyinstaller
pyinstaller --noconfirm --clean --onefile --windowed --name Khoa-NAS-PC khoa_nas_pc.py
~~~
