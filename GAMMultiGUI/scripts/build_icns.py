#!/usr/bin/env python3
import argparse
import struct
from pathlib import Path

ELEMENTS = [
    ('icp4', 'icon_16x16.png'),
    ('icp5', 'icon_16x16@2x.png'),
    ('icp6', 'icon_32x32@2x.png'),
    ('ic07', 'icon_128x128.png'),
    ('ic08', 'icon_128x128@2x.png'),
    ('ic09', 'icon_256x256@2x.png'),
    ('ic10', 'icon_512x512@2x.png'),
]


def parse_args():
    script_dir = Path(__file__).resolve().parent
    default_assets = script_dir.parent / 'Assets'

    parser = argparse.ArgumentParser(description='Build an .icns from an iconset folder.')
    parser.add_argument('--iconset', type=Path, default=default_assets / 'Icon.iconset', help='Path to iconset directory.')
    parser.add_argument('--output', type=Path, default=default_assets / 'AppIcon.icns', help='Output .icns path.')
    return parser.parse_args()


def main():
    args = parse_args()
    missing = [name for _, name in ELEMENTS if not (args.iconset / name).exists()]
    if missing:
        raise SystemExit(f'Missing required iconset files in {args.iconset}: {", ".join(missing)}')

    blocks = []
    for code, file_name in ELEMENTS:
        path = args.iconset / file_name
        data = path.read_bytes()
        block = code.encode('ascii') + struct.pack('>I', len(data) + 8) + data
        blocks.append(block)

    total_size = 8 + sum(len(b) for b in blocks)
    payload = b'icns' + struct.pack('>I', total_size) + b''.join(blocks)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(payload)
    print(args.output)


if __name__ == '__main__':
    main()
