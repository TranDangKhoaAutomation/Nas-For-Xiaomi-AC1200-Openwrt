"""Compile simple LuCI translations to the native LMO format.

Format and SuperFastHash follow OpenWrt LuCI lmo.c / po2lmo.c.
No plural or contextual entries are used by this page.
"""
import json
import re
import struct
from pathlib import Path

MASK = 0xFFFFFFFF


def sfh(data):
    value = len(data)
    offset = 0
    for _ in range(len(data) >> 2):
        value = (value + int.from_bytes(data[offset:offset + 2], 'little')) & MASK
        temp = (int.from_bytes(data[offset + 2:offset + 4], 'little') << 11) ^ value
        value = ((value << 16) ^ temp) & MASK
        value = (value + (value >> 11)) & MASK
        offset += 4
    rem = len(data) & 3
    if rem == 3:
        value = (value + int.from_bytes(data[offset:offset + 2], 'little')) & MASK
        value = (value ^ (value << 16)) & MASK
        char = data[offset + 2]
        if char >= 128:
            char -= 256
        value = (value ^ (char << 18)) & MASK
        value = (value + (value >> 11)) & MASK
    elif rem == 2:
        value = (value + int.from_bytes(data[offset:offset + 2], 'little')) & MASK
        value = (value ^ (value << 11)) & MASK
        value = (value + (value >> 17)) & MASK
    elif rem == 1:
        char = data[offset]
        if char >= 128:
            char -= 256
        value = (value + char) & MASK
        value = (value ^ (value << 10)) & MASK
        value = (value + (value >> 1)) & MASK
    value = (value ^ (value << 3)) & MASK
    value = (value + (value >> 5)) & MASK
    value = (value ^ (value << 4)) & MASK
    value = (value + (value >> 17)) & MASK
    value = (value ^ (value << 25)) & MASK
    return (value + (value >> 6)) & MASK


def compile_catalog(mapping, target):
    strings = bytearray()
    entries = []
    seen = set()
    for key, translated in mapping.items():
        canonical = re.sub(r'\s+', ' ', key).strip().encode()
        key_id = sfh(canonical)
        if key_id in seen:
            raise ValueError('Duplicate translation hash')
        seen.add(key_id)
        data = translated.encode()
        entries.append((key_id, 1, len(strings), len(data)))
        strings.extend(data)
        strings.extend(b'\0' * (-len(data) % 4))
    index = len(strings)
    for entry in sorted(entries):
        strings.extend(struct.pack('>IIII', *entry))
    strings.extend(struct.pack('>I', index))
    target.write_bytes(strings)


if __name__ == '__main__':
    base = Path(__file__).resolve().parent
    mapping = json.loads((base / 'vi.json').read_text(encoding='utf-8'))
    mapping.update(json.loads((base / 'tailscale.vi.json').read_text(encoding='utf-8')))
    compile_catalog(mapping, base / 'nas-disks.vi.lmo')
    compile_catalog({key: key.split('\x01')[-1] for key in mapping}, base / 'nas-disks.en.lmo')
    print(f'Compiled {len(mapping)} Vietnamese translations')
