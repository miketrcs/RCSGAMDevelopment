#!/usr/bin/env python3
import argparse
import colorsys
import hashlib
import math
import struct
import zlib
from pathlib import Path


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


def mix(a, b, t):
    return a + (b - a) * t


def smoothstep(edge0, edge1, x):
    t = clamp((x - edge0) / (edge1 - edge0))
    return t * t * (3 - 2 * t)


def blend(dst, src, alpha):
    ia = 1.0 - alpha
    return (
        int(dst[0] * ia + src[0] * alpha),
        int(dst[1] * ia + src[1] * alpha),
        int(dst[2] * ia + src[2] * alpha),
    )


def write_png_rgba(path: Path, width: int, height: int, rgba_rows):
    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack('!I', len(data))
            + tag
            + data
            + struct.pack('!I', zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    raw = bytearray()
    for row in rgba_rows:
        raw.append(0)
        raw.extend(row)

    ihdr = struct.pack('!IIBBBBB', width, height, 8, 6, 0, 0, 0)
    payload = (
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', ihdr)
        + chunk(b'IDAT', zlib.compress(bytes(raw), 9))
        + chunk(b'IEND', b'')
    )
    path.write_bytes(payload)


def rounded_rect_alpha(xf, yf, x0, y0, x1, y1, r):
    cx = min(max(xf, x0 + r), x1 - r)
    cy = min(max(yf, y0 + r), y1 - r)
    d = math.hypot(xf - cx, yf - cy)

    if x0 + r <= xf <= x1 - r and y0 <= yf <= y1:
        return 1.0
    if y0 + r <= yf <= y1 - r and x0 <= xf <= x1:
        return 1.0

    return 1.0 - smoothstep(r - 1.5, r + 1.5, d)


def hsv_rgb(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, clamp(s), clamp(v))
    return (int(r * 255), int(g * 255), int(b * 255))


def palette_for(theme: str):
    theme_key = theme.strip().lower()
    if theme_key == 'google-vault-light':
        return {
            'base1': (234, 241, 250),
            'base2': (214, 226, 243),
            'steel': (74, 87, 110),
            'steel_dark': (48, 62, 84),
            'archive_gray': (101, 116, 145),
            'archive_dark': (63, 77, 104),
            'vault_inner': (204, 215, 232),
            'spoke': (64, 79, 106),
            'hub1': (56, 71, 95),
            'hub2': (99, 114, 140),
            'highlight': (255, 255, 255),
            'google_blue': (66, 133, 244),
            'google_red': (234, 67, 53),
            'google_yellow': (251, 188, 5),
            'google_green': (52, 168, 83),
        }

    if theme_key == 'google-vault':
        return {
            'base1': (15, 30, 64),
            'base2': (31, 47, 88),
            'steel': (211, 220, 232),
            'steel_dark': (128, 141, 162),
            'archive_gray': (162, 176, 196),
            'archive_dark': (104, 117, 142),
            'vault_inner': (227, 233, 242),
            'spoke': (112, 124, 145),
            'hub1': (120, 132, 150),
            'hub2': (164, 174, 191),
            'highlight': (255, 255, 255),
            'google_blue': (66, 133, 244),
            'google_red': (234, 67, 53),
            'google_yellow': (251, 188, 5),
            'google_green': (52, 168, 83),
        }

    seed = hashlib.sha256(theme.encode('utf-8')).digest()
    base_h = seed[0] / 255.0
    alt_h = (base_h + 0.08 + (seed[1] / 255.0) * 0.15) % 1.0
    accent_h = (base_h + 0.5 + (seed[2] / 255.0) * 0.2) % 1.0

    ring_sat = 0.55 + (seed[3] / 255.0) * 0.3
    ring_val = 0.82 + (seed[4] / 255.0) * 0.15
    background_sat = 0.48 + (seed[5] / 255.0) * 0.25
    background_v1 = 0.18 + (seed[6] / 255.0) * 0.18
    background_v2 = min(0.56, background_v1 + 0.12 + (seed[7] / 255.0) * 0.12)

    steel_h = (accent_h + 0.1) % 1.0
    steel_sat = 0.11 + (seed[8] / 255.0) * 0.14

    return {
        'base1': hsv_rgb(base_h, background_sat, background_v1),
        'base2': hsv_rgb(alt_h, background_sat * 0.88, background_v2),
        'steel': hsv_rgb(steel_h, steel_sat, 0.93),
        'steel_dark': hsv_rgb(steel_h, steel_sat * 1.4, 0.66),
        'archive_gray': hsv_rgb(steel_h, steel_sat * 1.1, 0.77),
        'archive_dark': hsv_rgb(steel_h, steel_sat * 1.3, 0.56),
        'vault_inner': hsv_rgb(steel_h, steel_sat * 0.85, 0.96),
        'spoke': hsv_rgb(steel_h, steel_sat * 1.55, 0.62),
        'hub1': hsv_rgb(steel_h, steel_sat * 1.45, 0.57),
        'hub2': hsv_rgb(steel_h, steel_sat * 1.2, 0.74),
        'highlight': (255, 255, 255),
        'google_blue': hsv_rgb(base_h, ring_sat, ring_val),
        'google_red': hsv_rgb(base_h + 0.22, ring_sat, ring_val),
        'google_yellow': hsv_rgb(base_h + 0.44, ring_sat, ring_val),
        'google_green': hsv_rgb(base_h + 0.66, ring_sat, ring_val),
    }


def render_google_vault_icon(size: int, theme: str):
    cx = size / 2
    cy = size / 2
    p = palette_for(theme)

    rr = size * 0.215
    rect_x0, rect_y0 = size * 0.137, size * 0.117
    rect_x1, rect_y1 = size - rect_x0, size - rect_y0

    ring_r_outer = size * 0.285
    ring_r_inner = size * 0.213

    vault_r = size * 0.166
    vault_inner = size * 0.115

    archive_w = size * 0.342
    archive_h = size * 0.096
    archive_y = size * 0.645

    rows = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            xf = x + 0.5
            yf = y + 0.5

            alpha_mask = rounded_rect_alpha(xf, yf, rect_x0, rect_y0, rect_x1, rect_y1, rr)
            if alpha_mask <= 0.001:
                row.extend((0, 0, 0, 0))
                continue

            gy = (yf - rect_y0) / (rect_y1 - rect_y0)
            gx = (xf - rect_x0) / (rect_x1 - rect_x0)
            tbg = clamp(gy * 0.9 + gx * 0.1)
            col = (
                int(mix(p['base1'][0], p['base2'][0], tbg)),
                int(mix(p['base1'][1], p['base2'][1], tbg)),
                int(mix(p['base1'][2], p['base2'][2], tbg)),
            )

            rx = xf - cx
            ry = yf - cy
            r = math.hypot(rx, ry)
            a = (math.degrees(math.atan2(ry, rx)) + 360.0) % 360.0

            if ring_r_inner <= r <= ring_r_outer:
                ring_alpha = smoothstep(ring_r_inner, ring_r_inner + 2.5, r)
                ring_alpha *= (1.0 - smoothstep(ring_r_outer - 2.5, ring_r_outer, r))
                segment = None
                if 320 <= a or a < 35:
                    segment = p['google_blue']
                elif 45 <= a < 125:
                    segment = p['google_red']
                elif 135 <= a < 215:
                    segment = p['google_yellow']
                elif 225 <= a < 305:
                    segment = p['google_green']
                if segment is not None:
                    col = blend(col, segment, 0.95 * ring_alpha)

            if r <= vault_r:
                grad = clamp(r / vault_r)
                vault_col = (
                    int(mix(p['steel'][0], p['steel_dark'][0], grad * 0.5)),
                    int(mix(p['steel'][1], p['steel_dark'][1], grad * 0.5)),
                    int(mix(p['steel'][2], p['steel_dark'][2], grad * 0.5)),
                )
                edge = 1.0 - smoothstep(vault_r - 2.5, vault_r, r)
                col = blend(col, vault_col, edge)

            if r <= vault_inner:
                col = blend(col, p['vault_inner'], 0.75)
                for sa in (0, 60, 120, 180, 240, 300):
                    da = abs(((a - sa + 180) % 360) - 180)
                    if da < 4.0 and size * 0.035 < r < size * 0.103:
                        spoke_alpha = (1.0 - da / 4.0) * 0.9
                        col = blend(col, p['spoke'], spoke_alpha)

            if r <= size * 0.031:
                col = blend(col, p['hub1'], 1.0)
            elif r <= size * 0.043:
                col = blend(col, p['hub2'], 0.9)

            ax0 = cx - archive_w / 2
            ax1 = cx + archive_w / 2
            ay0 = archive_y
            ay1 = archive_y + archive_h
            if ax0 <= xf <= ax1 and ay0 <= yf <= ay1:
                shade = clamp((yf - ay0) / archive_h)
                ac = (
                    int(mix(p['archive_gray'][0], p['archive_dark'][0], shade * 0.8)),
                    int(mix(p['archive_gray'][1], p['archive_dark'][1], shade * 0.8)),
                    int(mix(p['archive_gray'][2], p['archive_dark'][2], shade * 0.8)),
                )
                col = blend(col, ac, 0.92)

                hx0 = cx - size * 0.061
                hx1 = cx + size * 0.061
                hy0 = ay0 + size * 0.033
                hy1 = ay0 + size * 0.051
                if hx0 <= xf <= hx1 and hy0 <= yf <= hy1:
                    col = blend(col, p['spoke'], 0.95)

            hr = math.hypot(xf - (cx - size * 0.166), yf - (cy - size * 0.205))
            if hr < size * 0.215:
                h = (1 - hr / (size * 0.215)) ** 1.8
                col = blend(col, p['highlight'], h * 0.14)

            row.extend((col[0], col[1], col[2], int(alpha_mask * 255)))

        rows.append(row)
    return rows


def parse_args():
    script_dir = Path(__file__).resolve().parent
    default_assets = script_dir.parent / 'Assets'
    parser = argparse.ArgumentParser(description='Generate reusable icon master PNG.')
    parser.add_argument('--output', type=Path, default=default_assets / 'AppIcon-1024.png', help='Output PNG path.')
    parser.add_argument('--size', type=int, default=1024, help='Canvas size in pixels (default: 1024).')
    parser.add_argument(
        '--theme',
        default='google-vault',
        help='Visual theme label (free-form). Custom values generate a deterministic palette.',
    )
    return parser.parse_args()


def main():
    args = parse_args()
    if args.size < 256:
        raise SystemExit('--size must be >= 256')

    rows = render_google_vault_icon(args.size, args.theme)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    write_png_rgba(args.output, args.size, args.size, rows)
    print(args.output)


if __name__ == '__main__':
    main()
