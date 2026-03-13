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


def circle_alpha(xf, yf, cx, cy, r, feather=2.0):
    d = math.hypot(xf - cx, yf - cy)
    return 1.0 - smoothstep(r - feather, r + feather, d)


def segment_distance(px, py, x0, y0, x1, y1):
    dx = x1 - x0
    dy = y1 - y0
    length_sq = dx * dx + dy * dy
    if length_sq == 0:
        return math.hypot(px - x0, py - y0)
    t = ((px - x0) * dx + (py - y0) * dy) / length_sq
    t = clamp(t)
    qx = x0 + t * dx
    qy = y0 + t * dy
    return math.hypot(px - qx, py - qy)


def stroke_alpha(px, py, x0, y0, x1, y1, width, feather=1.5):
    d = segment_distance(px, py, x0, y0, x1, y1)
    return 1.0 - smoothstep(width - feather, width + feather, d)


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
            'base1': (225, 234, 248),
            'base2': (205, 219, 240),
            'paper': (248, 250, 252),
            'paper_shadow': (191, 201, 219),
            'paper_line': (174, 190, 214),
            'header': (90, 160, 127),
            'header_dark': (55, 116, 90),
            'mail': (255, 255, 255),
            'mail_shadow': (211, 219, 233),
            'mail_line': (108, 129, 166),
            'badge': (221, 74, 57),
            'badge_dark': (161, 44, 32),
            'badge_mark': (255, 255, 255),
            'highlight': (255, 255, 255),
        }

    if theme_key == 'google-vault':
        return {
            'base1': (22, 35, 68),
            'base2': (38, 59, 105),
            'paper': (245, 248, 252),
            'paper_shadow': (143, 161, 188),
            'paper_line': (137, 156, 187),
            'header': (83, 171, 129),
            'header_dark': (49, 122, 88),
            'mail': (252, 253, 255),
            'mail_shadow': (191, 203, 224),
            'mail_line': (115, 137, 175),
            'badge': (234, 67, 53),
            'badge_dark': (170, 43, 31),
            'badge_mark': (255, 255, 255),
            'highlight': (255, 255, 255),
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
        'paper': hsv_rgb(steel_h, steel_sat * 0.28, 0.98),
        'paper_shadow': hsv_rgb(steel_h, steel_sat * 0.85, 0.74),
        'paper_line': hsv_rgb(steel_h, steel_sat * 1.1, 0.78),
        'header': hsv_rgb(base_h + 0.31, ring_sat * 0.75, 0.74),
        'header_dark': hsv_rgb(base_h + 0.31, ring_sat * 0.8, 0.52),
        'mail': (252, 253, 255),
        'mail_shadow': hsv_rgb(steel_h, steel_sat * 0.65, 0.84),
        'mail_line': hsv_rgb(steel_h, steel_sat * 1.4, 0.67),
        'badge': hsv_rgb(base_h + 0.08, ring_sat * 0.9, 0.92),
        'badge_dark': hsv_rgb(base_h + 0.08, ring_sat, 0.66),
        'badge_mark': (255, 255, 255),
        'highlight': (255, 255, 255),
    }


def render_google_vault_icon(size: int, theme: str):
    cx = size / 2
    cy = size / 2
    p = palette_for(theme)

    rr = size * 0.215
    rect_x0, rect_y0 = size * 0.137, size * 0.117
    rect_x1, rect_y1 = size - rect_x0, size - rect_y0

    doc_x0 = size * 0.24
    doc_y0 = size * 0.18
    doc_x1 = size * 0.79
    doc_y1 = size * 0.80
    doc_r = size * 0.06

    env_x0 = size * 0.29
    env_y0 = size * 0.35
    env_x1 = size * 0.73
    env_y1 = size * 0.61
    env_r = size * 0.04

    badge_cx = size * 0.73
    badge_cy = size * 0.70
    badge_r = size * 0.12

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

            shadow_alpha = rounded_rect_alpha(
                xf, yf,
                doc_x0 + size * 0.01, doc_y0 + size * 0.018,
                doc_x1 + size * 0.01, doc_y1 + size * 0.018,
                doc_r
            )
            if shadow_alpha > 0.0:
                col = blend(col, p['paper_shadow'], shadow_alpha * 0.22)

            doc_alpha = rounded_rect_alpha(xf, yf, doc_x0, doc_y0, doc_x1, doc_y1, doc_r)
            if doc_alpha > 0.0:
                doc_grad = clamp((yf - doc_y0) / (doc_y1 - doc_y0))
                doc_col = (
                    int(mix(p['paper'][0], p['paper_shadow'][0], doc_grad * 0.16)),
                    int(mix(p['paper'][1], p['paper_shadow'][1], doc_grad * 0.16)),
                    int(mix(p['paper'][2], p['paper_shadow'][2], doc_grad * 0.16)),
                )
                col = blend(col, doc_col, doc_alpha)

                header_y = doc_y0 + size * 0.11
                if yf <= header_y:
                    head_t = clamp((yf - doc_y0) / max(1.0, header_y - doc_y0))
                    head_col = (
                        int(mix(p['header'][0], p['header_dark'][0], head_t * 0.7)),
                        int(mix(p['header'][1], p['header_dark'][1], head_t * 0.7)),
                        int(mix(p['header'][2], p['header_dark'][2], head_t * 0.7)),
                    )
                    col = blend(col, head_col, doc_alpha * 0.96)

                if doc_x0 + size * 0.05 <= xf <= doc_x1 - size * 0.05 and header_y + size * 0.03 <= yf <= doc_y1 - size * 0.06:
                    rel_x = xf - doc_x0
                    rel_y = yf - doc_y0
                    row_marks = (0.22, 0.31, 0.40, 0.49, 0.58, 0.67)
                    col_marks = (0.14, 0.37, 0.60)
                    for mark in row_marks:
                        line_y = (doc_y1 - doc_y0) * mark + doc_y0
                        alpha = stroke_alpha(xf, yf, doc_x0 + size * 0.07, line_y, doc_x1 - size * 0.07, line_y, size * 0.0024)
                        if alpha > 0.0:
                            col = blend(col, p['paper_line'], alpha * 0.7)
                    for mark in col_marks:
                        line_x = (doc_x1 - doc_x0) * mark + doc_x0
                        alpha = stroke_alpha(xf, yf, line_x, header_y + size * 0.03, line_x, doc_y1 - size * 0.07, size * 0.0022)
                        if alpha > 0.0:
                            col = blend(col, p['paper_line'], alpha * 0.45)

            env_shadow = rounded_rect_alpha(
                xf, yf,
                env_x0 + size * 0.012, env_y0 + size * 0.016,
                env_x1 + size * 0.012, env_y1 + size * 0.016,
                env_r
            )
            if env_shadow > 0.0:
                col = blend(col, p['mail_shadow'], env_shadow * 0.28)

            env_alpha = rounded_rect_alpha(xf, yf, env_x0, env_y0, env_x1, env_y1, env_r)
            if env_alpha > 0.0:
                env_grad = clamp((yf - env_y0) / (env_y1 - env_y0))
                env_col = (
                    int(mix(p['mail'][0], p['mail_shadow'][0], env_grad * 0.09)),
                    int(mix(p['mail'][1], p['mail_shadow'][1], env_grad * 0.09)),
                    int(mix(p['mail'][2], p['mail_shadow'][2], env_grad * 0.09)),
                )
                col = blend(col, env_col, env_alpha)

                center_x = (env_x0 + env_x1) / 2
                mid_y = env_y0 + (env_y1 - env_y0) * 0.56
                line_w = size * 0.0052
                for x0, y0, x1, y1, a in (
                    (env_x0 + size * 0.03, env_y0 + size * 0.05, center_x, mid_y, 1.0),
                    (env_x1 - size * 0.03, env_y0 + size * 0.05, center_x, mid_y, 1.0),
                    (env_x0 + size * 0.035, env_y1 - size * 0.04, center_x, mid_y, 0.82),
                    (env_x1 - size * 0.035, env_y1 - size * 0.04, center_x, mid_y, 0.82),
                    (env_x0 + size * 0.03, env_y0 + size * 0.03, env_x1 - size * 0.03, env_y0 + size * 0.03, 0.5),
                ):
                    alpha = stroke_alpha(xf, yf, x0, y0, x1, y1, line_w)
                    if alpha > 0.0:
                        col = blend(col, p['mail_line'], alpha * a)

                stamp_x0 = env_x1 - size * 0.125
                stamp_y0 = env_y0 + size * 0.04
                stamp_x1 = env_x1 - size * 0.04
                stamp_y1 = env_y0 + size * 0.13
                if stamp_x0 <= xf <= stamp_x1 and stamp_y0 <= yf <= stamp_y1:
                    stamp_t = clamp((yf - stamp_y0) / max(1.0, stamp_y1 - stamp_y0))
                    stamp_col = (
                        int(mix(p['header'][0], p['header_dark'][0], stamp_t * 0.55)),
                        int(mix(p['header'][1], p['header_dark'][1], stamp_t * 0.55)),
                        int(mix(p['header'][2], p['header_dark'][2], stamp_t * 0.55)),
                    )
                    col = blend(col, stamp_col, env_alpha * 0.96)

                    inner_margin = size * 0.01
                    scallop_r = size * 0.006
                    for sx, sy in (
                        (stamp_x0 + inner_margin, stamp_y0 + inner_margin),
                        (stamp_x1 - inner_margin, stamp_y0 + inner_margin),
                        (stamp_x0 + inner_margin, stamp_y1 - inner_margin),
                        (stamp_x1 - inner_margin, stamp_y1 - inner_margin),
                    ):
                        inv = circle_alpha(xf, yf, sx, sy, scallop_r, feather=size * 0.002)
                        if inv > 0.0:
                            col = blend(col, p['mail'], inv * 0.95)

                    seal_alpha = circle_alpha(
                        xf, yf,
                        (stamp_x0 + stamp_x1) / 2,
                        (stamp_y0 + stamp_y1) / 2,
                        size * 0.018,
                        feather=size * 0.0025
                    )
                    if seal_alpha > 0.0:
                        col = blend(col, p['mail'], seal_alpha * 0.9)

            badge_alpha = circle_alpha(xf, yf, badge_cx, badge_cy, badge_r, feather=size * 0.004)
            if badge_alpha > 0.0:
                badge_t = clamp((yf - (badge_cy - badge_r)) / (badge_r * 2))
                badge_col = (
                    int(mix(p['badge'][0], p['badge_dark'][0], badge_t * 0.6)),
                    int(mix(p['badge'][1], p['badge_dark'][1], badge_t * 0.6)),
                    int(mix(p['badge'][2], p['badge_dark'][2], badge_t * 0.6)),
                )
                col = blend(col, badge_col, badge_alpha)

                can_x0 = badge_cx - size * 0.037
                can_x1 = badge_cx + size * 0.037
                can_y0 = badge_cy - size * 0.03
                can_y1 = badge_cy + size * 0.038
                lid_y = can_y0 - size * 0.013
                if can_x0 <= xf <= can_x1 and can_y0 <= yf <= can_y1:
                    col = blend(col, p['badge_mark'], badge_alpha * 0.96)
                if badge_cx - size * 0.05 <= xf <= badge_cx + size * 0.05 and lid_y <= yf <= lid_y + size * 0.012:
                    col = blend(col, p['badge_mark'], badge_alpha * 0.96)
                if badge_cx - size * 0.018 <= xf <= badge_cx + size * 0.018 and lid_y - size * 0.012 <= yf <= lid_y - size * 0.003:
                    col = blend(col, p['badge_mark'], badge_alpha * 0.96)
                for offset in (-0.018, 0.0, 0.018):
                    alpha = stroke_alpha(
                        xf, yf,
                        badge_cx + size * offset, can_y0 + size * 0.008,
                        badge_cx + size * offset, can_y1 - size * 0.01,
                        size * 0.0025
                    )
                    if alpha > 0.0:
                        col = blend(col, p['badge_dark'], alpha * 0.55)

            hr = math.hypot(xf - (cx - size * 0.16), yf - (cy - size * 0.20))
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
