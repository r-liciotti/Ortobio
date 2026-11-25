#!/usr/bin/env python3
"""
Detailed 24x28 Stardew-Valley-inspired farmer sprite sheet generator for Ortobio.
Outputs:
  - assets/tiles/farmer_sheet.png         (4 cols x 6 rows of 24x28 = 96x168)
  - assets/previews/farmer_sheet_preview.png (6x zoomed QA preview)
Rows:
  0: Idle & Walk (0=idle, 1=walk L, 2=idle, 3=walk R)
  1: Spade / Vanga (0=windup, 1=dig down, 2=lift clod, 3=recover)
  2: Rake / Rastrello (0=reach, 1=pull back, 2=push forward, 3=recover)
  3: Water / Annaffiatoio (0=hold can, 1=tilt & pour A, 2=tilt & pour B, 3=lower)
  4: Seed / Semina (0=pouch, 1=toss seeds, 2=scatter, 3=recover)
  5: Harvest / Raccolta (0=reach down, 1=pull up, 2=hold high, 3=recover)
"""

import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILES_DIR = os.path.join(ROOT, "assets", "tiles")
PREVIEW_DIR = os.path.join(ROOT, "assets", "previews")

C = {
    ".": (0, 0, 0, 0),
    "sh": (24, 16, 12, 96),     # Ground contact shadow
    "k": (48, 30, 22, 255),     # Warm dark outline
    # Straw hat & ribbon
    "h0": (176, 122, 34, 255),  # Straw shadow
    "h1": (218, 164, 56, 255),  # Straw mid
    "h2": (246, 206, 94, 255),  # Straw highlight
    "h3": (254, 232, 154, 255), # Sunlit straw rim
    "rb": (182, 46, 42, 255),   # Hat band red
    # Hair (warm chestnut)
    "hr0": (86, 50, 32, 255),
    "hr1": (124, 76, 46, 255),
    # Skin & blush
    "s0": (204, 148, 110, 255), # Skin shadow
    "s1": (236, 186, 146, 255), # Skin mid
    "s2": (250, 212, 178, 255), # Skin highlight
    "bl": (232, 134, 124, 255), # Rosy cheek
    "ey": (42, 28, 24, 255),    # Eyes
    # Shirt (warm cozy plaid/terracotta)
    "t0": (146, 44, 38, 255),
    "t1": (196, 66, 52, 255),
    "t2": (228, 102, 78, 255),
    # Overalls (Stardew denim blue)
    "o0": (40, 68, 114, 255),
    "o1": (62, 104, 164, 255),
    "o2": (96, 142, 202, 255),
    "bt": (240, 198, 76, 255),  # Brass overall button
    # Boots (warm leather)
    "b0": (74, 44, 26, 255),
    "b1": (112, 68, 40, 255),
    "b2": (148, 94, 56, 255),
    # Tools (wood handle + steel + watering can + seeds)
    "w0": (92, 58, 32, 255),
    "w1": (142, 92, 52, 255),
    "w2": (184, 128, 76, 255),
    "m0": (96, 106, 118, 255),
    "m1": (158, 170, 184, 255),
    "m2": (218, 228, 238, 255),
    "c0": (44, 102, 164, 255),  # Watering can dark
    "c1": (78, 152, 214, 255),  # Watering can mid
    "c2": (154, 214, 246, 255), # Watering can shine / drops
    "sd": (244, 216, 112, 255), # Golden seeds
    "lf": (98, 176, 66, 255),   # Harvest leaf
}


def write_png(path, width, height, pixels):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    raw_rows = []
    for y in range(height):
        row = bytearray([0])
        for x in range(width):
            r, g, b, a = pixels[y * width + x]
            row.extend((r, g, b, a))
        raw_rows.append(bytes(row))
    raw = b"".join(raw_rows)

    def chunk(tag, data):
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    idat = zlib.compress(raw, level=9)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def blend_over(dst, src):
    sr, sg, sb, sa = src
    if sa == 0:
        return dst
    if sa == 255:
        return src
    dr, dg, db, da = dst
    a = sa / 255.0
    inv = 1.0 - a
    return (
        int(sr * a + dr * inv),
        int(sg * a + dg * inv),
        int(sb * a + db * inv),
        min(255, int(sa + da * inv)),
    )


def new_frame():
    return [(0, 0, 0, 0)] * (24 * 28)


def put(px, x, y, tok):
    if 0 <= x < 24 and 0 <= y < 28:
        px[y * 24 + x] = blend_over(px[y * 24 + x], C[tok])


def fill_rect(px, x0, y0, w, h, tok):
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            put(px, x, y, tok)


def draw_line_px(px, x0, y0, x1, y1, tok):
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(steps + 1):
        x = int(round(x0 + (x1 - x0) * i / steps))
        y = int(round(y0 + (y1 - y0) * i / steps))
        put(px, x, y, tok)


def draw_shadow(px, cx=11.5, cy=25.0, rx=6.0, ry=2.0):
    for y in range(28):
        for x in range(24):
            dx = (x - cx) / rx
            dy = (y - cy) / ry
            if dx * dx + dy * dy <= 1.0:
                put(px, x, y, "sh")


def draw_farmer_base(px, body_dy=0, lean_x=0, leg_mode="idle", arm_pose="idle"):
    """
    Draws a detailed 24x28 Stardew-Valley-style farmer facing RIGHT.
    Centered around x=11, feet at y=24..25.
    """
    draw_shadow(px, 11.5 + lean_x * 0.4, 25.2, 6.2, 1.9)
    ox = lean_x
    oy = body_dy

    # --- 1. LEGS & BOOTS ---
    if leg_mode == "idle":
        # Left & right legs with denim shading + leather boots
        for lx in (8, 12):
            fill_rect(px, lx + ox, 19 + oy, 3, 4, "k")
            fill_rect(px, lx + 1 + ox, 19 + oy, 1, 3, "o1")
            put(px, lx + ox, 19 + oy, "o0")
            # Boot
            fill_rect(px, lx + ox, 23 + oy, 4, 3, "k")
            put(px, lx + 1 + ox, 23 + oy, "b2")
            put(px, lx + 2 + ox, 23 + oy, "b1")
            put(px, lx + 1 + ox, 24 + oy, "b1")
            put(px, lx + 2 + ox, 24 + oy, "b0")
    elif leg_mode == "walk_l":
        # Back leg (left) stepped back, front leg (right) stepped forward
        fill_rect(px, 6 + ox, 19 + oy, 3, 4, "k")
        put(px, 7 + ox, 20 + oy, "o0")
        fill_rect(px, 5 + ox, 22 + oy, 4, 3, "k")
        put(px, 6 + ox, 23 + oy, "b1")
        put(px, 7 + ox, 23 + oy, "b0")
        # Front leg
        fill_rect(px, 13 + ox, 19 + oy, 3, 4, "k")
        put(px, 14 + ox, 20 + oy, "o2")
        fill_rect(px, 13 + ox, 23 + oy, 4, 3, "k")
        put(px, 14 + ox, 24 + oy, "b2")
        put(px, 15 + ox, 24 + oy, "b1")
    elif leg_mode == "walk_r":
        # Front leg stepped back, back leg forward
        fill_rect(px, 7 + ox, 19 + oy, 3, 4, "k")
        put(px, 8 + ox, 20 + oy, "o2")
        fill_rect(px, 7 + ox, 23 + oy, 4, 3, "k")
        put(px, 8 + ox, 24 + oy, "b2")
        put(px, 9 + ox, 24 + oy, "b1")
        # Back leg lifted slightly
        fill_rect(px, 12 + ox, 19 + oy, 3, 3, "k")
        put(px, 13 + ox, 20 + oy, "o0")
        fill_rect(px, 13 + ox, 21 + oy, 4, 3, "k")
        put(px, 14 + ox, 22 + oy, "b1")
        put(px, 15 + ox, 22 + oy, "b0")
    elif leg_mode == "stance":
        # Wide grounded work stance
        fill_rect(px, 7 + ox, 19 + oy, 3, 4, "k")
        put(px, 8 + ox, 20 + oy, "o0")
        fill_rect(px, 6 + ox, 23 + oy, 4, 3, "k")
        put(px, 7 + ox, 24 + oy, "b1")
        put(px, 8 + ox, 24 + oy, "b0")
        fill_rect(px, 13 + ox, 19 + oy, 3, 4, "k")
        put(px, 14 + ox, 20 + oy, "o2")
        fill_rect(px, 13 + ox, 23 + oy, 4, 3, "k")
        put(px, 14 + ox, 24 + oy, "b2")
        put(px, 15 + ox, 24 + oy, "b1")

    # --- 2. TORSO (SHIRT + OVERALLS WITH STRAPS & BUTTONS) ---
    fill_rect(px, 7 + ox, 13 + oy, 9, 7, "k")
    # Shirt base
    fill_rect(px, 8 + ox, 14 + oy, 7, 5, "t1")
    fill_rect(px, 8 + ox, 14 + oy, 2, 4, "t2")
    fill_rect(px, 13 + ox, 14 + oy, 2, 4, "t0")
    # Overalls bib & waist
    fill_rect(px, 8 + ox, 16 + oy, 7, 3, "o1")
    fill_rect(px, 9 + ox, 15 + oy, 5, 2, "o2")
    fill_rect(px, 13 + ox, 16 + oy, 2, 3, "o0")
    # Straps & brass buttons
    put(px, 9 + ox, 14 + oy, "o1")
    put(px, 13 + ox, 14 + oy, "o0")
    put(px, 9 + ox, 15 + oy, "bt")
    put(px, 13 + ox, 15 + oy, "bt")

    # --- 3. HEAD, HAIR, EYES & ROSY CHEEKS ---
    fill_rect(px, 7 + ox, 7 + oy, 9, 7, "k")
    fill_rect(px, 8 + ox, 8 + oy, 7, 5, "s1")
    fill_rect(px, 8 + ox, 8 + oy, 3, 3, "s2")
    fill_rect(px, 13 + ox, 9 + oy, 2, 4, "s0")
    # Hair tufts on left/back
    fill_rect(px, 7 + ox, 8 + oy, 2, 4, "hr0")
    put(px, 8 + ox, 8 + oy, "hr1")
    put(px, 8 + ox, 9 + oy, "hr1")
    # Eyes (facing slightly right, Stardew 2px tall eyes)
    put(px, 10 + ox, 10 + oy, "ey")
    put(px, 10 + ox, 11 + oy, "ey")
    put(px, 13 + ox, 10 + oy, "ey")
    put(px, 13 + ox, 11 + oy, "ey")
    # Rosy cheeks
    put(px, 9 + ox, 12 + oy, "bl")
    put(px, 14 + ox, 12 + oy, "bl")

    # --- 4. DETAILED STRAW HAT WITH RED BAND ---
    # Crown
    fill_rect(px, 7 + ox, 2 + oy, 9, 4, "k")
    fill_rect(px, 8 + ox, 3 + oy, 7, 2, "h2")
    fill_rect(px, 8 + ox, 3 + oy, 3, 1, "h3")
    fill_rect(px, 13 + ox, 3 + oy, 2, 2, "h1")
    # Red hat ribbon
    fill_rect(px, 8 + ox, 5 + oy, 7, 1, "rb")
    # Wide brim
    fill_rect(px, 4 + ox, 6 + oy, 15, 3, "k")
    fill_rect(px, 5 + ox, 7 + oy, 13, 1, "h1")
    fill_rect(px, 6 + ox, 7 + oy, 7, 1, "h2")
    fill_rect(px, 14 + ox, 7 + oy, 4, 1, "h0")

    # --- 5. ARMS (POSABLE) ---
    if arm_pose == "idle":
        # Back arm (left) & front arm (right) resting at sides
        fill_rect(px, 6 + ox, 14 + oy, 2, 4, "k")
        put(px, 6 + ox, 15 + oy, "t2")
        put(px, 6 + ox, 17 + oy, "s1")
        fill_rect(px, 15 + ox, 14 + oy, 2, 4, "k")
        put(px, 15 + ox, 15 + oy, "t1")
        put(px, 15 + ox, 17 + oy, "s1")
    elif arm_pose == "raise":
        # Arms raised up/forward holding tool overhead
        fill_rect(px, 14 + ox, 10 + oy, 3, 5, "k")
        put(px, 15 + ox, 13 + oy, "t2")
        put(px, 15 + ox, 12 + oy, "t1")
        put(px, 15 + ox, 11 + oy, "s2")
    elif arm_pose == "forward":
        # Arms extended forward toward tile
        fill_rect(px, 14 + ox, 14 + oy, 5, 3, "k")
        put(px, 15 + ox, 15 + oy, "t2")
        put(px, 16 + ox, 15 + oy, "t1")
        put(px, 17 + ox, 15 + oy, "s2")
    elif arm_pose == "down":
        # Arms driving tool down into soil
        fill_rect(px, 14 + ox, 15 + oy, 4, 4, "k")
        put(px, 15 + ox, 16 + oy, "t1")
        put(px, 16 + ox, 17 + oy, "s1")
    elif arm_pose == "celebrate":
        # Both arms lifted happily (harvest!)
        fill_rect(px, 5 + ox, 10 + oy, 3, 5, "k")
        put(px, 6 + ox, 13 + oy, "t2")
        put(px, 6 + ox, 11 + oy, "s2")
        fill_rect(px, 15 + ox, 10 + oy, 3, 5, "k")
        put(px, 16 + ox, 13 + oy, "t1")
        put(px, 16 + ox, 11 + oy, "s2")


def make_frame(row, col):
    px = new_frame()

    # Row 0: Idle & Walk
    if row == 0:
        if col == 0 or col == 2:
            draw_farmer_base(px, body_dy=0, leg_mode="idle", arm_pose="idle")
        elif col == 1:
            draw_farmer_base(px, body_dy=-1, leg_mode="walk_l", arm_pose="idle")
        else:
            draw_farmer_base(px, body_dy=-1, leg_mode="walk_r", arm_pose="idle")
        return px

    # Row 1: Spade / Vanga (farmer physically swings spade into soil)
    if row == 1:
        if col == 0:
            draw_farmer_base(px, body_dy=-1, lean_x=-1, leg_mode="stance", arm_pose="raise")
            # Spade held high
            draw_line_px(px, 14, 11, 19, 3, "w1")
            fill_rect(px, 18, 1, 4, 4, "k")
            fill_rect(px, 19, 2, 2, 2, "m2")
        elif col == 1:
            draw_farmer_base(px, body_dy=1, lean_x=1, leg_mode="stance", arm_pose="down")
            # Spade driven down into soil
            draw_line_px(px, 16, 16, 21, 23, "w1")
            fill_rect(px, 19, 21, 4, 5, "k")
            fill_rect(px, 20, 22, 2, 3, "m1")
            put(px, 20, 22, "m2")
        elif col == 2:
            draw_farmer_base(px, body_dy=0, lean_x=1, leg_mode="stance", arm_pose="forward")
            # Lifting clod
            draw_line_px(px, 16, 15, 22, 19, "w1")
            fill_rect(px, 20, 17, 4, 4, "k")
            fill_rect(px, 21, 18, 2, 2, "m2")
            put(px, 22, 16, "b1")
        else:
            draw_farmer_base(px, body_dy=0, lean_x=0, leg_mode="idle", arm_pose="idle")
        return px

    # Row 2: Rake / Rastrello (farmer reaches out & sweeps rake across ground)
    if row == 2:
        if col == 0:
            draw_farmer_base(px, body_dy=0, lean_x=1, leg_mode="stance", arm_pose="forward")
            draw_line_px(px, 16, 15, 22, 21, "w1")
            fill_rect(px, 20, 20, 4, 4, "k")
            put(px, 21, 21, "m2")
            put(px, 22, 22, "m1")
            put(px, 21, 23, "m0")
            put(px, 23, 23, "m0")
        elif col == 1:
            draw_farmer_base(px, body_dy=1, lean_x=0, leg_mode="stance", arm_pose="down")
            draw_line_px(px, 15, 16, 19, 22, "w1")
            fill_rect(px, 17, 21, 5, 3, "k")
            put(px, 18, 22, "m2")
            put(px, 20, 22, "m1")
        elif col == 2:
            draw_farmer_base(px, body_dy=0, lean_x=1, leg_mode="stance", arm_pose="forward")
            draw_line_px(px, 16, 15, 22, 22, "w2")
            fill_rect(px, 20, 21, 4, 3, "k")
            put(px, 21, 22, "m2")
            put(px, 22, 22, "m1")
        else:
            draw_farmer_base(px, body_dy=0, lean_x=0, leg_mode="idle", arm_pose="idle")
        return px

    # Row 3: Water / Annaffiatoio (farmer holds & tilts watering can with water stream)
    if row == 3:
        if col == 0:
            draw_farmer_base(px, body_dy=0, lean_x=0, leg_mode="stance", arm_pose="forward")
            fill_rect(px, 16, 14, 6, 5, "k")
            fill_rect(px, 17, 15, 4, 3, "c1")
            put(px, 17, 15, "c2")
            put(px, 22, 15, "c1")
        elif col == 1 or col == 2:
            draw_farmer_base(px, body_dy=1, lean_x=1, leg_mode="stance", arm_pose="forward")
            # Tilted blue watering can
            fill_rect(px, 16, 15, 6, 5, "k")
            fill_rect(px, 17, 16, 4, 3, "c1")
            put(px, 17, 16, "c2")
            put(px, 22, 18, "c0")
            # Water stream droplets coming out of spout
            dy = 0 if col == 1 else 2
            put(px, 22, 20 + dy, "c2")
            put(px, 23, 21 + dy, "c1")
            put(px, 21, 22 + dy, "c2")
            put(px, 23, 23 + dy, "c2")
        else:
            draw_farmer_base(px, body_dy=0, lean_x=0, leg_mode="idle", arm_pose="idle")
        return px

    # Row 4: Seed / Semina (farmer tosses golden seeds by hand)
    if row == 4:
        if col == 0:
            draw_farmer_base(px, body_dy=0, lean_x=0, leg_mode="stance", arm_pose="down")
            put(px, 17, 17, "sd")
        elif col == 1:
            draw_farmer_base(px, body_dy=-1, lean_x=1, leg_mode="stance", arm_pose="forward")
            put(px, 19, 15, "sd")
            put(px, 21, 14, "sd")
            put(px, 22, 16, "sd")
        elif col == 2:
            draw_farmer_base(px, body_dy=0, lean_x=1, leg_mode="stance", arm_pose="forward")
            put(px, 20, 19, "sd")
            put(px, 22, 20, "sd")
            put(px, 21, 22, "sd")
        else:
            draw_farmer_base(px, body_dy=0, lean_x=0, leg_mode="idle", arm_pose="idle")
        return px

    # Row 5: Harvest / Raccolta (farmer bends down then lifts hands up happily!)
    if row == 5:
        if col == 0:
            draw_farmer_base(px, body_dy=2, lean_x=1, leg_mode="stance", arm_pose="down")
        elif col == 1:
            draw_farmer_base(px, body_dy=0, lean_x=0, leg_mode="stance", arm_pose="forward")
            put(px, 18, 14, "lf")
        elif col == 2:
            draw_farmer_base(px, body_dy=-1, lean_x=0, leg_mode="idle", arm_pose="celebrate")
        else:
            draw_farmer_base(px, body_dy=0, lean_x=0, leg_mode="idle", arm_pose="idle")
        return px

    return px


def generate():
    cols, rows = 4, 6
    fw, fh = 24, 28
    sw, sh = cols * fw, rows * fh
    sheet = [(0, 0, 0, 0)] * (sw * sh)

    for r in range(rows):
        for c in range(cols):
            frame = make_frame(r, c)
            for y in range(fh):
                for x in range(fw):
                    sheet[(r * fh + y) * sw + (c * fw + x)] = frame[y * fw + x]

    write_png(os.path.join(TILES_DIR, "farmer_sheet.png"), sw, sh, sheet)

    # 5x zoomed preview on warm parchment background
    scale = 5
    pw, ph = sw * scale, sh * scale
    prev = [(238, 228, 206, 255)] * (pw * ph)
    for y in range(sh):
        for x in range(sw):
            col = sheet[y * sw + x]
            for sy in range(scale):
                for sx in range(scale):
                    idx = (y * scale + sy) * pw + (x * scale + sx)
                    prev[idx] = blend_over(prev[idx], col)
    write_png(os.path.join(PREVIEW_DIR, "farmer_sheet_preview.png"), pw, ph, prev)
    print("Generated detailed 24x28 Stardew-style farmer_sheet.png!")


if __name__ == "__main__":
    generate()
