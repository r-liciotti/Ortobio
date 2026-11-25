#!/usr/bin/env python3
"""
Autonomous pixel-art & SFX asset generator for Ortobio v0.1+.
Generates:
  - assets/tiles/field_atlas.png       (16x16 organic grass, status icons, tools)
  - assets/tiles/soil_autotile.png     (16x16 4-bit autotiled rounded 3D soil beds + inner corners)
  - assets/tiles/crops_atlas.png       (16x20 3/4-perspective volumetric crops with ground shadows)
  - assets/ui/icon_*.png               (16x16 crisp UI icons)
  - assets/audio/sfx_*.wav             (synthesized tactile SFX)
  - assets/previews/v01_visual_qa.png  (zoomed mockup of connected beds + 3D crops)
"""

import math
import os
import random
import struct
import wave
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILES_DIR = os.path.join(ROOT, "assets", "tiles")
UI_DIR = os.path.join(ROOT, "assets", "ui")
AUDIO_DIR = os.path.join(ROOT, "assets", "audio")
PREVIEW_DIR = os.path.join(ROOT, "assets", "previews")

# Warm Cozy Mediterranean / Stardew-inspired Palette
P = {
    ".": (0, 0, 0, 0),
    "sh": (26, 18, 14, 92),      # Soft ground drop shadow
    "k": (52, 34, 24, 255),      # Warm dark outline
    # Soil Dry (warm terracotta / ochre-brown)
    "sd0": (96, 62, 38, 255),    # Deep shadow / lip
    "sd1": (128, 86, 52, 255),   # Dark furrow
    "sd2": (156, 108, 66, 255),  # Mid warm dry soil
    "sd3": (182, 132, 84, 255),  # Highlight ridge / bottom bevel
    "sd4": (202, 154, 104, 255), # Bright dry crumb
    # Soil Wet (rich dark chocolate)
    "sw0": (58, 36, 24, 255),    # Deep wet shadow
    "sw1": (78, 50, 34, 255),    # Wet furrow
    "sw2": (98, 64, 44, 255),    # Mid wet soil
    "sw3": (118, 80, 56, 255),   # Wet highlight
    # Grass (softer, less noisy, Stardew-style warm greens)
    "g0": (54, 98, 44, 255),     # Deep leaf / shadow green
    "g1": (78, 128, 54, 255),    # Tuft dark green
    "g2": (106, 156, 66, 255),   # Base meadow green
    "g3": (126, 174, 78, 255),   # Soft sunlit patch
    "g4": (168, 206, 104, 255),  # Bright leaf highlight
    "g5": (204, 228, 142, 255),  # Sun-kissed tip
    # Cabbage sage greens
    "c0": (74, 118, 64, 255),
    "c1": (118, 162, 92, 255),
    "c2": (162, 202, 128, 255),
    "c3": (214, 234, 178, 255),
    # Reds (tomato / radish)
    "r0": (148, 34, 34, 255),
    "r1": (202, 52, 44, 255),
    "r2": (236, 86, 64, 255),
    "r3": (250, 152, 118, 255),
    # Wood / stems / stakes
    "b0": (76, 48, 30, 255),
    "b1": (110, 72, 44, 255),
    "b2": (146, 98, 60, 255),
    "b3": (184, 134, 86, 255),
    # Accents
    "wh": (246, 240, 222, 255),
    "y0": (202, 144, 38, 255),
    "y1": (244, 206, 78, 255),
    "bl0": (52, 108, 166, 255),
    "bl1": (94, 168, 220, 255),
    "bl2": (182, 228, 248, 255),
    "pd0": (56, 72, 86, 180),    # Natural dark puddle
    "pd1": (126, 174, 204, 200), # Puddle sky reflection
    # Skin & farmer clothes
    "sk0": (212, 158, 118, 255),
    "sk1": (240, 194, 154, 255),
    "ov0": (44, 78, 128, 255),
    "ov1": (68, 114, 174, 255),
    "s0": (106, 114, 126, 255),
    "s1": (162, 172, 184, 255),
    "s2": (218, 226, 234, 255),
    "st0": (118, 86, 48, 255),
    "st1": (168, 132, 74, 255),
    "st2": (204, 172, 106, 255),
    # Pink blossoms (trifoglio)
    "pk0": (186, 86, 124, 255),
    "pk1": (232, 138, 174, 255),
    "pk2": (252, 206, 224, 255),
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


def new_canvas(w, h, color=(0, 0, 0, 0)):
    return [color] * (w * h)


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


def stamp(atlas, atlas_w, ox, oy, tile_px, tw, th, alpha_blend=False):
    for y in range(th):
        for x in range(tw):
            c = tile_px[y * tw + x]
            idx = (oy + y) * atlas_w + (ox + x)
            if alpha_blend:
                atlas[idx] = blend_over(atlas[idx], c)
            else:
                atlas[idx] = c


def parse_sprite(lines, w=16, h=16, bg="."):
    px = new_canvas(w, h, P[bg])
    for y in range(min(h, len(lines))):
        tokens = lines[y].split()
        for x in range(min(w, len(tokens))):
            px[y * w + x] = P[tokens[x]]
    return px


def make_organic_grass(variant=0):
    """Soft, calm meadow grass with subtle sunlit tufts (Stardew style, low noise)."""
    px = new_canvas(16, 16, P["g2"])
    # Subtle soft patch variation
    if variant == 0:
        # Clean calm grass with 2 gentle tufts
        for x, y in [(3, 5), (4, 5), (4, 4), (11, 12), (12, 12), (11, 11)]:
            px[y * 16 + x] = P["g1"]
        for x, y in [(4, 3), (12, 10), (8, 7), (9, 7)]:
            px[y * 16 + x] = P["g3"]
    elif variant == 1:
        # Organic grass tufts + tiny wildflower cluster (no circular blotch)
        for x, y in [(6, 6), (7, 6), (8, 7), (7, 8), (5, 7), (9, 8)]:
            px[y * 16 + x] = P["g3"]
        px[11 * 16 + 4] = P["g1"]
        px[10 * 16 + 4] = P["wh"]
        px[11 * 16 + 5] = P["g1"]
        px[4 * 16 + 11] = P["y1"]
        px[5 * 16 + 11] = P["g1"]
    elif variant == 2:
        # Gentle grass blades
        for x, y in [(2, 10), (3, 10), (3, 9), (9, 4), (10, 4), (10, 3), (13, 13)]:
            px[y * 16 + x] = P["g1"]
        for x, y in [(3, 8), (10, 2), (6, 12), (7, 12)]:
            px[y * 16 + x] = P["g3"]
    else:
        # Very clean tile so meadow breathes
        for x, y in [(6, 6), (7, 6), (12, 9)]:
            px[y * 16 + x] = P["g3"]
    return px


def make_soil_autotile_cell(mask, style="rastrellato", wet=False, waterlogged=False):
    """
    Generates one 16x16 soil tile for 4-bit mask:
      bit 0 (1): North connected
      bit 1 (2): East connected
      bit 2 (4): South connected
      bit 3 (8): West connected
    Features:
      - Seamless merging between connected neighbors
      - Organic rounded outer corners (3px radius)
      - 3/4 Stardew-style recessed top shadow lip + warm raised bottom rim
    """
    n = bool(mask & 1)
    e = bool(mask & 2)
    s = bool(mask & 4)
    w = bool(mask & 8)

    if wet or waterlogged:
        c_lip = P["sw0"]
        c_dark = P["sw1"]
        c_mid = P["sw2"]
        c_light = P["sw3"]
        c_crumb = P["sw3"]
    else:
        c_lip = P["sd0"]
        c_dark = P["sd1"]
        c_mid = P["sd2"]
        c_light = P["sd3"]
        c_crumb = P["sd4"]

    px = new_canvas(16, 16, (0, 0, 0, 0))

    # Determine soil bounding box inside 16x16 (1px outer grass margin on open sides)
    top_y = 0 if n else 1
    bot_y = 15 if s else 14
    left_x = 0 if w else 1
    right_x = 15 if e else 14

    def is_inside(x, y):
        if x < left_x or x > right_x or y < top_y or y > bot_y:
            return False
        # Round outer corners smoothly (radius ~3.0 px)
        if not n and not w:
            dx = (left_x + 3) - x
            dy = (top_y + 3) - y
            if dx > 0 and dy > 0 and (dx * dx + dy * dy) > 10:
                return False
        if not n and not e:
            dx = x - (right_x - 3)
            dy = (top_y + 3) - y
            if dx > 0 and dy > 0 and (dx * dx + dy * dy) > 10:
                return False
        if not s and not w:
            dx = (left_x + 3) - x
            dy = y - (bot_y - 3)
            if dx > 0 and dy > 0 and (dx * dx + dy * dy) > 10:
                return False
        if not s and not e:
            dx = x - (right_x - 3)
            dy = y - (bot_y - 3)
            if dx > 0 and dy > 0 and (dx * dx + dy * dy) > 10:
                return False
        return True

    # 1. Fill soil interior with organic texture
    for y in range(16):
        for x in range(16):
            if not is_inside(x, y):
                continue
            col = c_mid
            if style == "vangato":
                # Sculpted rounded dirt clods (organic bumpy texture)
                h = ((x * 37 + y * 17) ^ (x * 11)) & 15
                if (x + y * 2) % 5 == 0:
                    col = c_dark
                elif h == 2 or h == 9:
                    col = c_light
                elif h == 5:
                    col = c_crumb
            else:
                # Rastrellato: soft continuous horizontal seedbed rows
                row_mod = y % 4
                if row_mod == 0:
                    col = c_dark
                elif row_mod == 1:
                    col = c_light
                elif row_mod == 2:
                    col = c_mid
                else:
                    col = c_mid
                    if (x * 13 + y * 7) % 11 == 0:
                        col = c_dark
            px[y * 16 + x] = col

    # 2. Apply 3/4 Depth Rim Shading (recessed top shadow, warm bottom highlight, soft side bevel)
    for y in range(16):
        for x in range(16):
            if not is_inside(x, y):
                continue
            above_open = (y == 0 and not n) or (y > 0 and not is_inside(x, y - 1))
            above2_open = (y <= 1 and not n) or (y > 1 and not is_inside(x, y - 2))
            below_open = (y == 15 and not s) or (y < 15 and not is_inside(x, y + 1))
            below2_open = (y >= 14 and not s) or (y < 14 and not is_inside(x, y + 2))
            left_open = (x == 0 and not w) or (x > 0 and not is_inside(x - 1, y))
            right_open = (x == 15 and not e) or (x < 15 and not is_inside(x + 1, y))

            if above_open:
                # Dark recessed lip under overhanging grass
                px[y * 16 + x] = P["k"] if not wet else c_lip
            elif above2_open:
                # Inner cast shadow from the grass edge (gives real 3D recessed depth!)
                px[y * 16 + x] = c_lip
            elif below_open:
                # Bottom edge dark outline resting against grass
                px[y * 16 + x] = c_lip
            elif below2_open:
                # Warm sunlit bottom rim catching the light
                px[y * 16 + x] = c_light
            elif left_open or right_open:
                px[y * 16 + x] = c_lip

    # 3. Subtle outer drop shadow below the bottom edge onto the grass
    if not s:
        for x in range(16):
            if bot_y + 1 < 16 and is_inside(x, bot_y):
                px[(bot_y + 1) * 16 + x] = (34, 62, 26, 95)

    # 4. Natural rounded puddles if waterlogged (subtle shiny water pools, no harsh stripes)
    if waterlogged:
        puddles = [(5, 6), (6, 6), (7, 6), (6, 7), (10, 10), (11, 10), (10, 11)]
        for px_x, px_y in puddles:
            if is_inside(px_x, px_y) and px_y > top_y + 2 and px_y < bot_y - 1:
                px[px_y * 16 + px_x] = blend_over(px[px_y * 16 + px_x], P["pd0"])
        for px_x, px_y in [(5, 6), (10, 10)]:
            if is_inside(px_x, px_y) and px_y > top_y + 2 and px_y < bot_y - 1:
                px[px_y * 16 + px_x] = blend_over(px[px_y * 16 + px_x], P["pd1"])

    return px


def make_inner_corner_patch(corner):
    """
    Small 16x16 transparent overlay with a soft rounded grass notch in one corner
    when two orthogonal neighbors are tilled but the diagonal neighbor is grass.
    corner: 0=NW, 1=NE, 2=SW, 3=SE
    """
    px = new_canvas(16, 16, (0, 0, 0, 0))
    if corner == 0: # NW
        pts = [(0, 0, "g2"), (1, 0, "g1"), (0, 1, "g1"), (2, 0, "k"), (1, 1, "k"), (0, 2, "k")]
    elif corner == 1: # NE
        pts = [(15, 0, "g2"), (14, 0, "g1"), (15, 1, "g1"), (13, 0, "k"), (14, 1, "k"), (15, 2, "k")]
    elif corner == 2: # SW
        pts = [(0, 15, "g2"), (1, 15, "g1"), (0, 14, "g1"), (2, 15, "sd0"), (1, 14, "sd0"), (0, 13, "sd0")]
    else: # SE
        pts = [(15, 15, "g2"), (14, 15, "g1"), (15, 14, "g1"), (13, 15, "sd0"), (14, 14, "sd0"), (15, 13, "sd0")]
    for x, y, tok in pts:
        px[y * 16 + x] = P[tok]
    return px


def draw_oval_shadow(px, w, h, cx, cy, rx, ry):
    for y in range(h):
        for x in range(w):
            dx = (x - cx) / max(0.5, rx)
            dy = (y - cy) / max(0.5, ry)
            if dx * dx + dy * dy <= 1.0:
                px[y * w + x] = blend_over(px[y * w + x], P["sh"])


def make_crop_3d(crop_id, stage):
    """
    Generates a 16x20 3/4-perspective volumetric crop sprite.
    Bottom 16x16 aligns with the tile; top 4px allow taller plants to overlap
    upward for authentic Stardew Valley depth!
    """
    w, h = 16, 20
    px = new_canvas(w, h, (0, 0, 0, 0))

    if stage == 0:
        # Planted seeds tucked into soil
        for x, y, c in [(5, 11, "sd4"), (6, 12, "k"), (10, 13, "sd4"), (11, 14, "k"), (7, 15, "sd4")]:
            px[y * w + x] = P[c]
        return px

    if stage == 1:
        # Soft ground shadow + lively 3D sprout
        draw_oval_shadow(px, w, h, 7.5, 16.0, 3.2, 1.4)
        sprite = parse_sprite([
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . k k . . k k . . . . .",
            ". . . . k g5 g4 k g4 g3 k . . .",
            ". . . . k g3 g2 g1 g2 g1 k . . .",
            ". . . . . k k g1 g0 k k . . . .",
            ". . . . . . . k g0 k . . . . . .",
            ". . . . . . . k g0 k . . . . . .",
            ". . . . . . . . k k . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
        ], w, h)
        stamp(px, w, 0, 0, sprite, w, h, alpha_blend=True)
        return px

    if stage == 5:
        # Drooping frost/heat-withered plant
        draw_oval_shadow(px, w, h, 7.5, 16.5, 4.5, 1.6)
        sprite = parse_sprite([
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . k k . . k k . . . . .",
            ". . . . k st2 st1 k st1 st0 k .",
            ". . . k st1 st0 k st1 k st0 k .",
            ". . . . k k . . k b1 k . k k . .",
            ". . . . . . . . k b0 k . . . . .",
            ". . . . . . . k b0 b1 k . . . .",
            ". . . . . . . . k k k . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
        ], w, h)
        stamp(px, w, 0, 0, sprite, w, h, alpha_blend=True)
        return px

    if crop_id == "ravanello":
        if stage == 2:
            draw_oval_shadow(px, w, h, 7.5, 16.2, 4.0, 1.5)
            sprite = parse_sprite([
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . k k . . . k k . . . .",
                ". . . . k g5 g4 k k g4 g3 k . .",
                ". . . . k g3 g2 g3 g2 g1 k . . .",
                ". . . . . k g2 g1 g1 g0 k . . .",
                ". . . . . . k g1 g0 g0 k . . . .",
                ". . . . . . . k g0 g0 k . . . .",
                ". . . . . . . . k g0 k . . . . .",
                ". . . . . . . . . k k . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
            ], w, h)
            stamp(px, w, 0, 0, sprite, w, h, alpha_blend=True)
        elif stage == 3:
            draw_oval_shadow(px, w, h, 7.5, 16.5, 4.6, 1.7)
            sprite = parse_sprite([
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . k k . . . . k k . . . .",
                ". . . k g5 g4 k . k g4 g3 k . .",
                ". . . k g3 g2 g3 k g2 g1 k . . .",
                ". . . . k g2 g1 g1 g1 g0 k . . .",
                ". . . . . k k g0 g0 g0 k . . . .",
                ". . . . . . k k k k k . . . . .",
                ". . . . . k r3 r2 r1 r0 k . . .",
                ". . . . . k r2 r1 r1 r0 k . . .",
                ". . . . . . k r1 r0 r0 k . . . .",
                ". . . . . . . k k k k . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
            ], w, h)
            stamp(px, w, 0, 0, sprite, w, h, alpha_blend=True)
        else:
            # Mature plump 3D radish peeking out of the soil with leafy crown
            draw_oval_shadow(px, w, h, 7.5, 16.8, 5.2, 1.9)
            sprite = parse_sprite([
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . k k . . . . . . k k . . .",
                ". . k g5 g4 k . k k k g4 g3 k .",
                ". . k g4 g2 g3 k g4 g3 g2 g1 k .",
                ". . . k g2 g1 g2 g2 g1 g1 g0 k .",
                ". . . . k k g0 g1 g0 g0 k k . .",
                ". . . . . . k k k k k . . . . .",
                ". . . . . k r3 r3 r2 r1 k . . .",
                ". . . . k r3 r2 r2 r1 r0 k . . .",
                ". . . . k r2 r2 r1 r1 r0 k . . .",
                ". . . . k r1 r1 r1 r0 r0 k . . .",
                ". . . . . k wh r1 r0 r0 k . . .",
                ". . . . . . k wh wh r0 k . . . .",
                ". . . . . . . k k wh k . . . . .",
                ". . . . . . . . . k . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
            ], w, h)
            stamp(px, w, 0, 0, sprite, w, h, alpha_blend=True)

    elif crop_id == "pomodoro":
        if stage == 2:
            draw_oval_shadow(px, w, h, 7.5, 16.8, 4.5, 1.7)
            sprite = parse_sprite([
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . k k . . . . . . .",
                ". . . . . . k b3 b2 k . . . . .",
                ". . . . . k g4 g3 b1 k . . . . .",
                ". . . . k g4 g2 g1 g3 k . . . .",
                ". . . . k g2 g1 g0 g2 g1 k . . .",
                ". . . . . k g1 g0 b1 g0 k . . .",
                ". . . . k g3 g2 g0 b1 k . . . .",
                ". . . . . k g1 g0 b0 k . . . . .",
                ". . . . . . k g0 b0 k . . . . .",
                ". . . . . . . k b0 k . . . . . .",
                ". . . . . . . k b0 k . . . . . .",
                ". . . . . . . . k k . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
            ], w, h)
            stamp(px, w, 0, 0, sprite, w, h, alpha_blend=True)
        elif stage == 3:
            # Tall flowering tomato bush on wooden stake (rises into top 4px!)
            draw_oval_shadow(px, w, h, 7.5, 16.8, 5.2, 1.9)
            sprite = parse_sprite([
                ". . . . . . . k k . . . . . . .",
                ". . . . . . k b3 b2 k . . . . .",
                ". . . . . k g4 g3 b1 k . . . . .",
                ". . . . k g5 g3 g2 g3 k . . . .",
                ". . . k g4 y1 g1 g0 g2 g1 k . .",
                ". . . k g2 g1 g0 g1 y1 g0 k . .",
                ". . . . k g1 g2 g0 g0 g1 k . . .",
                ". . . k g4 g3 y1 g1 g2 g0 k . .",
                ". . . k g2 g1 g0 g0 g1 g0 k . .",
                ". . . . k g0 g1 b1 g0 k k . . .",
                ". . . . . k g1 b1 g0 k . . . . .",
                ". . . . . . k b1 b0 k . . . . .",
                ". . . . . . . k b0 k . . . . . .",
                ". . . . . . . k b0 k . . . . . .",
                ". . . . . . . k b0 k . . . . . .",
                ". . . . . . . . k k . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
            ], w, h)
            stamp(px, w, 0, 0, sprite, w, h, alpha_blend=True)
        else:
            # Lush mature tomato vine on stake with glossy 3D red tomatoes!
            draw_oval_shadow(px, w, h, 7.5, 16.8, 5.6, 2.0)
            sprite = parse_sprite([
                ". . . . . . . k k . . . . . . .",
                ". . . . . . k b3 b2 k . . . . .",
                ". . . . . k g5 g4 b1 k . . . . .",
                ". . . . k g4 g3 g2 g3 g1 k . . .",
                ". . . k g4 r3 r2 g1 g2 g1 k . .",
                ". . . k g2 r2 r1 g0 g1 g0 k . .",
                ". . . k g1 r0 g0 g2 r3 r2 k . .",
                ". . . . k g0 g1 g1 r2 r1 k . . .",
                ". . . k g3 r3 r2 g0 r0 g0 k . .",
                ". . . k g2 r2 r1 g0 g1 k . . . .",
                ". . . . k r0 g0 b1 g0 k . . . .",
                ". . . . . k g0 b1 b0 k . . . . .",
                ". . . . . . k b1 b0 k . . . . .",
                ". . . . . . . k b0 k . . . . . .",
                ". . . . . . . k b0 k . . . . . .",
                ". . . . . . . . k k . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
            ], w, h)
            stamp(px, w, 0, 0, sprite, w, h, alpha_blend=True)

    elif crop_id == "cavolo_verza":
        if stage == 2:
            draw_oval_shadow(px, w, h, 7.5, 15.2, 4.4, 1.5)
            sprite = parse_sprite([
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . k k k k k . . . . . .",
                ". . . . k c2 c3 c2 c1 k . . . .",
                ". . . k c1 c2 c2 c1 c0 k . . . .",
                ". . . k g1 c1 c1 c0 g0 k . . . .",
                ". . . . k g0 c0 g0 g0 k . . . .",
                ". . . . . k k k k k k . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
            ], w, h)
            stamp(px, w, 0, 0, sprite, w, h, alpha_blend=True)
        elif stage == 3:
            draw_oval_shadow(px, w, h, 7.5, 15.5, 5.4, 1.7)
            sprite = parse_sprite([
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . k k k k k k . . . . .",
                ". . . . k c2 c3 c3 c2 c1 k . . .",
                ". . . k c1 c2 c3 c2 c1 c0 k . .",
                ". . k g1 c1 c2 c2 c1 c0 g0 k . .",
                ". . k g1 c0 c1 c1 c0 c0 g0 k . .",
                ". . . k g0 g1 c0 c0 g0 g0 k . .",
                ". . . . k g0 g0 g0 g0 g0 k . . .",
                ". . . . . k k k k k k k . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
            ], w, h)
            stamp(px, w, 0, 0, sprite, w, h, alpha_blend=True)
        else:
            # Plump 3D rounded Savoy cabbage anchored directly on its ground shadow
            draw_oval_shadow(px, w, h, 7.5, 15.8, 6.2, 1.9)
            sprite = parse_sprite([
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . k k k k k k . . . . .",
                ". . . k k c2 c3 c3 c2 k k . . .",
                ". . k g2 c2 c3 wh c3 c2 g1 k . .",
                ". k g2 g1 c1 c3 c3 c2 c1 g0 k .",
                ". k g1 c1 c1 c2 c2 c1 c0 g0 k .",
                ". k g0 c0 c1 c1 c1 c0 c0 g0 k .",
                ". . k g0 g1 c0 c0 c0 g0 g0 k . .",
                ". . . k g0 g0 g1 g0 g0 g0 k . .",
                ". . . . k k g0 g0 g0 k k . . . .",
                ". . . . . . k k k k . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
            ], w, h)
            stamp(px, w, 0, 0, sprite, w, h, alpha_blend=True)

    elif crop_id == "piselli":
        if stage == 2:
            draw_oval_shadow(px, w, h, 7.5, 16.5, 4.4, 1.6)
            sprite = parse_sprite([
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . k k . . k k . . . . .",
                ". . . . k b3 b2 k k b2 b3 k . . .",
                ". . . . . k b1 k k b1 k . . . . .",
                ". . . . k k k b1 b2 k k . . . . .",
                ". . . k g5 g4 k b1 g4 k . . . . . .",
                ". . . k g3 g2 g3 b1 g2 g1 k . . .",
                ". . . . k g1 b1 g2 g1 b0 k . . .",
                ". . . k g4 g3 b1 g3 g2 b0 k . . .",
                ". . . k g2 g1 b0 g1 g0 k . . . .",
                ". . . . k g0 b0 k b0 k . . . . .",
                ". . . . . k b0 k k b0 k . . . . .",
                ". . . . . k b0 k k b0 k . . . . .",
                ". . . . . . k . . . k . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
            ], w, h)
            stamp(px, w, 0, 0, sprite, w, h, alpha_blend=True)
        elif stage == 3:
            # Climbing pea vine on bamboo trellis with delicate white blossoms
            draw_oval_shadow(px, w, h, 7.5, 16.7, 5.0, 1.8)
            sprite = parse_sprite([
                ". . . . . k k . . k k . . . . .",
                ". . . . k b3 b2 k k b2 b3 k . . .",
                ". . . . . k b1 g4 g3 b1 k . . . .",
                ". . . . k g4 g3 g2 g1 g2 k . . .",
                ". . . k g3 wh g1 b1 wh g3 k . . .",
                ". . . k wh y1 g0 g2 y1 wh g1 k . .",
                ". . . . k g1 g3 g1 b1 g0 k . . .",
                ". . . k g4 g2 g0 g3 g2 wh k . . .",
                ". . . k g2 g1 wh y1 g1 y1 k . . .",
                ". . . . k g0 g2 g0 b1 g0 k . . .",
                ". . . k g3 g2 b1 g2 g1 k . . . .",
                ". . . . k g1 b0 g1 g0 k . . . .",
                ". . . . . k b0 g0 b0 k . . . . .",
                ". . . . . k b0 k k b0 k . . . . .",
                ". . . . . k b0 k k b0 k . . . . .",
                ". . . . . . k . . . k . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
            ], w, h)
            stamp(px, w, 0, 0, sprite, w, h, alpha_blend=True)
        else:
            # Mature 3/4 pea vine heavy with plump bright green pods
            draw_oval_shadow(px, w, h, 7.5, 16.8, 5.4, 1.9)
            sprite = parse_sprite([
                ". . . . . . . . . . . . . . . .",
                ". . . . . k k . . k k . . . . .",
                ". . . . k b3 b2 k k b2 b3 k . . .",
                ". . . . k g4 b1 g3 g2 b1 k . . .",
                ". . . k g3 g2 g1 wh g1 g3 k . . .",
                ". . k g4 g2 g1 g2 y1 g4 g2 k . .",
                ". . k g1 c3 g5 k g0 k c3 g5 k . .",
                ". . k g2 g4 g1 k g2 g4 g1 k . . .",
                ". . . k g4 g1 g0 g1 g2 g4 g1 k . .",
                ". . k g3 g0 k c3 g5 k g1 g0 k . .",
                ". . k c3 g5 k g4 g1 k c3 g5 k . .",
                ". . . k g4 g1 g0 b1 k g4 g1 k . .",
                ". . . . k g1 b0 g1 g0 g1 k . . .",
                ". . . . . k b0 g0 b0 k k . . . .",
                ". . . . . k b0 k k b0 k . . . . .",
                ". . . . . . k . . . k . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
            ], w, h)
            stamp(px, w, 0, 0, sprite, w, h, alpha_blend=True)

    elif crop_id == "trifoglio":
        if stage == 2:
            draw_oval_shadow(px, w, h, 7.5, 15.6, 4.8, 1.6)
            sprite = parse_sprite([
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . k k . k k . . . . .",
                ". . . . k k g4 g3 k g3 k . . . .",
                ". . . k g4 c3 g2 g4 c3 g2 k . .",
                ". . . k g2 g1 g0 g2 g1 g0 k . .",
                ". . . . k g1 g2 g3 g1 g0 k . . .",
                ". . . . . k g0 g1 g0 k k . . . .",
                ". . . . . . k k k k . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
            ], w, h)
            stamp(px, w, 0, 0, sprite, w, h, alpha_blend=True)
        elif stage == 3:
            draw_oval_shadow(px, w, h, 7.5, 15.8, 5.8, 1.9)
            sprite = parse_sprite([
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . k k . . k k . . . . .",
                ". . . . k g4 g3 k g4 g3 k . . .",
                ". . k k g3 c3 g2 g3 c3 g2 k k .",
                ". k g4 g3 g1 g0 g2 g1 g0 g3 g2 k",
                ". k g2 c3 g2 g3 g4 c3 g2 g1 g0 k",
                ". k g1 g0 g1 g2 g1 g0 g1 g2 g0 k",
                ". . k g0 g2 g1 g0 g2 g1 g0 k k .",
                ". . . k g0 g1 g0 g0 g1 g0 k . .",
                ". . . . k k k k k k k k k . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
            ], w, h)
            stamp(px, w, 0, 0, sprite, w, h, alpha_blend=True)
        else:
            # Mature lush 3/4 clover cushion with tiny pink/white blossoms
            draw_oval_shadow(px, w, h, 7.5, 16.0, 6.4, 2.0)
            sprite = parse_sprite([
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . k k . . . . . . . .",
                ". . . . . k pk2 wh k . k k . . .",
                ". . . k k k pk1 pk0 k k wh pk2 k",
                ". . k g4 g3 g2 g1 g3 g4 pk1 pk0 k",
                ". k g4 c3 g2 g4 c3 g2 g3 g2 g1 k",
                ". k g2 g1 pk2 wh g1 g0 g4 c3 g0 k",
                ". k g3 g2 pk1 pk0 g3 g2 g1 g0 g0 k",
                ". k g1 c3 g1 g0 g4 c3 g1 pk2 wh k",
                ". . k g0 g2 g1 g2 g1 g0 pk1 pk0 k",
                ". . . k g0 g1 g0 g0 g1 g0 k k .",
                ". . . . k k k k k k k k k . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
                ". . . . . . . . . . . . . . . .",
            ], w, h)
            stamp(px, w, 0, 0, sprite, w, h, alpha_blend=True)

    return px


def make_tool_icon(tool_id):
    if tool_id == "compost":
        return parse_sprite([
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . k k k k . . . . .",
            ". . . . . . k sw2 sw1 sw0 k . . .",
            ". . . . . k sw2 sd3 sw1 sw0 k . .",
            ". . . . . k b3 b2 b2 b1 b0 k . .",
            ". . . . . . k k b1 b0 k k . . .",
            ". . . . . k b3 b2 b2 b1 b0 k . .",
            ". . . . k b3 b2 g4 g3 b2 b1 k .",
            ". . . . k b2 b2 g3 g2 b1 b0 k .",
            ". . . . k b2 b1 g2 b1 b1 b0 k .",
            ". . . k k b1 b1 b1 b0 b0 b0 k .",
            ". . k sw2 sw1 k b1 b0 b0 b0 k .",
            ". k sw2 sw1 sw0 sw0 k k k k k . .",
            ". . k k k k k . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
        ])
    if tool_id == "probe":
        return parse_sprite([
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . k k k . . . .",
            ". . . . . . . . k s2 s1 k k . .",
            ". . . . . . . . . k s1 s2 s1 k .",
            ". . . . . . . . . k s1 s0 k k .",
            ". . . . . . . . k s2 s0 k . . .",
            ". . . . . . . k s2 s1 k . . . .",
            ". . . . . . k s2 s1 k . . . . .",
            ". . . . . k s2 s0 k . . . . . .",
            ". . . . k s2 s0 k . . . . . . .",
            ". . . k g4 g3 k . . . . . . . .",
            ". . k y1 g4 k . . . . . . . . .",
            ". . k y1 k . . . . . . . . . . .",
            ". . . k . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
        ])
    if tool_id == "spade":
        return parse_sprite([
            ". . . . . . . . . . . k k . . .",
            ". . . . . . . . . . k b3 k . . .",
            ". . . . . . . . . k b2 b3 k . .",
            ". . . . . . . . . k b1 k . . . .",
            ". . . . . . . . k b2 k . . . . .",
            ". . . . . . . k b1 k . . . . . .",
            ". . . . . . k b1 k . . . . . . .",
            ". . . . . k s1 k . . . . . . . .",
            ". . . . k s2 s1 k . . . . . . .",
            ". . . k s2 s1 s0 k . . . . . . .",
            ". . k s1 s1 s0 k . . . . . . . .",
            ". . k s1 s0 s0 k . . . . . . . .",
            ". . k s0 s0 k . . . . . . . . .",
            ". . . k k k . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
        ])
    if tool_id == "rake":
        return parse_sprite([
            ". . . . . . . . . . . k k . . .",
            ". . . . . . . . . . k b3 k . . .",
            ". . . . . . . . . k b2 k . . . .",
            ". . . . . . . . k b1 k . . . . .",
            ". . . . . . . k b2 k . . . . . .",
            ". . . . . . k b1 k . . . . . . .",
            ". . . . k k k s1 k . . . . . . .",
            ". . . k s2 s1 s0 k . . . . . . .",
            ". . k s1 k s0 k s0 k . . . . . .",
            ". . k s0 k s0 k s0 k . . . . . .",
            ". . . k . . k . . k . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
        ])
    if tool_id == "water":
        return parse_sprite([
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . k k k k . . . . .",
            ". . . . . . k bl1 bl2 k . . . .",
            ". . k k . k bl1 k . k bl1 k . .",
            ". . k bl2 k bl0 k . k bl1 k . .",
            ". . . k bl1 bl0 k k k bl0 k . .",
            ". . . . k bl1 bl1 bl0 bl0 k . .",
            ". . . . k bl2 bl1 bl1 bl0 k . .",
            ". . . . k bl1 bl1 bl0 bl0 k . .",
            ". . . . k bl0 bl0 bl0 bl0 k . .",
            ". . . . . k k k k k k k . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
        ])
    return parse_sprite([
        ". . . . . k k k k . . . . . . .",
        ". . . k k bl2 bl2 k k . . . . .",
        ". . k bl2 wh . . bl1 k . . . . .",
        ". . k bl2 . . . . bl1 k . . . .",
        ". . k bl1 . . . . bl1 k . . . .",
        ". . . k bl1 . . bl0 k . . . . .",
        ". . . . k k k k k k . . . . . .",
        ". . . . . . . . k b2 k . . . . .",
        ". . . . . . . . . k b2 k . . . .",
        ". . . . . . . . . . k b1 k . . .",
        ". . . . . . . . . . . k b0 k . .",
        ". . . . . . . . . . . . k k . .",
        ". . . . . . . . . . . . . . . .",
        ". . . . . . . . . . . . . . . .",
        ". . . . . . . . . . . . . . . .",
        ". . . . . . . . . . . . . . . .",
    ])


def make_status_icon(icon_id):
    if icon_id == "drop":
        return parse_sprite([
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . k . . . . . . . .",
            ". . . . . . k bl2 k . . . . . .",
            ". . . . . k bl2 bl1 k . . . . .",
            ". . . . k bl2 bl1 bl1 k . . . .",
            ". . . . k bl1 bl1 bl0 k . . . .",
            ". . . . k bl1 bl0 bl0 k . . . .",
            ". . . . . k bl0 bl0 k . . . . .",
            ". . . . . . k k k k . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
        ])
    if icon_id == "frost":
        return parse_sprite([
            ". . . . . . . bl2 . . . . . . .",
            ". . . . bl2 . bl1 . bl2 . . . .",
            ". . . . . bl1 bl2 bl1 . . . . .",
            ". . bl2 . . . bl1 . . . bl2 . .",
            ". . . bl1 . bl2 bl2 . bl1 . . .",
            ". . bl1 bl2 bl1 wh bl1 bl2 bl1 .",
            ". . . bl1 . bl2 bl2 . bl1 . . .",
            ". . bl2 . . . bl1 . . . bl2 . .",
            ". . . . . bl1 bl2 bl1 . . . . .",
            ". . . . bl2 . bl1 . bl2 . . . .",
            ". . . . . . . bl2 . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
        ])
    if icon_id == "heat":
        return parse_sprite([
            ". . . . . . y1 . . . . . . . . .",
            ". . . y1 . . y1 . . y1 . . . . .",
            ". . . . . k y1 y1 k . . . . . .",
            ". . . . k y1 r1 r1 k . . . . . .",
            ". . y1 k y1 r1 r2 y1 k y1 . . .",
            ". . . . k r1 r1 y1 k . . . . . .",
            ". . . . . k y1 y1 k . . . . . .",
            ". . . y1 . . y1 . . y1 . . . . .",
            ". . . . . . y1 . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
        ])
    if icon_id == "sparkle":
        return parse_sprite([
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . y1 . . .",
            ". . . . . . . . . . . y1 wh y1 .",
            ". . . . . . . . . . . . y1 . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
        ])
    # Rounded yellow selection corners
    px = new_canvas(16, 16)
    c = P["y1"]
    for x, y in [
        (1, 0), (2, 0), (3, 0), (0, 1), (0, 2), (0, 3),
        (14, 0), (13, 0), (12, 0), (15, 1), (15, 2), (15, 3),
        (1, 15), (2, 15), (3, 15), (0, 14), (0, 13), (0, 12),
        (14, 15), (13, 15), (12, 15), (15, 14), (15, 13), (15, 12),
    ]:
        px[y * 16 + x] = c
    return px


def make_fertilized_overlay():
    """Cozy humus/compost speckles staying inside x=2..13, y=2..13."""
    px = new_canvas(16, 16)
    speckles = [
        # Dark organic humus crumbs
        (3, 3, "sw0"), (4, 3, "sd0"),
        (11, 4, "sd0"), (12, 4, "sw0"),
        (8, 6, "sw0"), (9, 6, "sd0"),
        (2, 8, "sd0"),
        (4, 10, "sw0"), (5, 11, "sd0"),
        (12, 10, "sw0"), (13, 10, "sd0"),
        (9, 12, "sw0"),
        # Warm organic bits
        (10, 3, "sd4"),
        (5, 5, "sd4"),
        (3, 8, "sd4"),
        (7, 9, "sd4"),
        (10, 12, "sd4"),
        # Tiny natural green-compost flecks
        (3, 6, "g1"),
        (11, 8, "g3"),
    ]
    for x, y, tok in speckles:
        px[y * 16 + x] = P[tok]
    return px


def make_farmer_frame(frame_idx):
    """
    Generates a 16x22 3/4-perspective cozy farmer sprite (straw hat, red shirt, blue overalls).
      0: Idle
      1: Walk A
      2: Walk B
      3: Work action
    """
    w, h = 16, 22
    px = new_canvas(w, h, (0, 0, 0, 0))
    draw_oval_shadow(px, w, h, 7.5, 19.5, 4.6, 1.6)

    if frame_idx == 0:
        lines = [
            ". . . . . . . . . . . . . . . .",
            ". . . . . k k k k k k . . . . .",
            ". . . . k y1 y1 y1 y0 k . . . .",
            ". . . k y1 y1 y1 y0 y0 k . . . .",
            ". . k k y0 y0 r1 r1 y0 k k . . .",
            ". k y1 y1 y1 y1 y0 y0 y0 y0 k .",
            ". . k k k k k k k k k k k k . .",
            ". . . . k sk1 sk1 sk1 sk0 k . .",
            ". . . . k sk1 k sk1 k sk0 k . .",
            ". . . . k sk1 sk1 sk1 sk0 k . .",
            ". . . . . k k k k k k . . . . .",
            ". . . . k r2 r1 ov1 ov1 r1 k . .",
            ". . . k r1 r1 ov1 ov1 ov0 r0 k .",
            ". . . k sk1 k ov1 y1 ov0 k sk0 k",
            ". . . . k k ov1 ov1 ov0 k k . .",
            ". . . . . k ov1 ov0 ov0 k . . .",
            ". . . . . k ov0 k k ov0 k . . .",
            ". . . . . k ov0 k k ov0 k . . .",
            ". . . . . k b1 k . k b0 k . . .",
            ". . . . . k k k . . k k k . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
        ]
    elif frame_idx == 1:
        lines = [
            ". . . . . k k k k k k . . . . .",
            ". . . . k y1 y1 y1 y0 k . . . .",
            ". . . k y1 y1 y1 y0 y0 k . . . .",
            ". . k k y0 y0 r1 r1 y0 k k . . .",
            ". k y1 y1 y1 y1 y0 y0 y0 y0 k .",
            ". . k k k k k k k k k k k k . .",
            ". . . . k sk1 sk1 sk1 sk0 k . .",
            ". . . . k sk1 k sk1 k sk0 k . .",
            ". . . . k sk1 sk1 sk1 sk0 k . .",
            ". . . . . k k k k k k . . . . .",
            ". . . . k r2 r1 ov1 ov1 r1 k . .",
            ". . . k r1 r1 ov1 ov1 ov0 r0 k .",
            ". . . k sk1 k ov1 y1 ov0 k sk0 k",
            ". . . . k k ov1 ov1 ov0 k k . .",
            ". . . . . k ov1 ov0 ov0 k . . .",
            ". . . . k ov0 k . k ov0 k . . .",
            ". . . . k b1 k . . k ov0 k . . .",
            ". . . . k k k . . . k b0 k . . .",
            ". . . . . . . . . . k k k . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
        ]
    elif frame_idx == 2:
        lines = [
            ". . . . . k k k k k k . . . . .",
            ". . . . k y1 y1 y1 y0 k . . . .",
            ". . . k y1 y1 y1 y0 y0 k . . . .",
            ". . k k y0 y0 r1 r1 y0 k k . . .",
            ". k y1 y1 y1 y1 y0 y0 y0 y0 k .",
            ". . k k k k k k k k k k k k . .",
            ". . . . k sk1 sk1 sk1 sk0 k . .",
            ". . . . k sk1 k sk1 k sk0 k . .",
            ". . . . k sk1 sk1 sk1 sk0 k . .",
            ". . . . . k k k k k k . . . . .",
            ". . . . k r2 r1 ov1 ov1 r1 k . .",
            ". . . k r1 r1 ov1 ov1 ov0 r0 k .",
            ". . . k sk1 k ov1 y1 ov0 k sk0 k",
            ". . . . k k ov1 ov1 ov0 k k . .",
            ". . . . . k ov1 ov0 ov0 k . . .",
            ". . . . . k ov0 k . k ov0 k . .",
            ". . . . . k ov0 k . . k b0 k . .",
            ". . . . . k b1 k . . . k k k . .",
            ". . . . . k k k . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
        ]
    else:
        # Work bounce (leaning slightly forward, arms active)
        lines = [
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . k k k k k k . . . . .",
            ". . . . k y1 y1 y1 y0 k . . . .",
            ". . . k y1 y1 y1 y0 y0 k . . . .",
            ". . k k y0 y0 r1 r1 y0 k k . . .",
            ". k y1 y1 y1 y1 y0 y0 y0 y0 k .",
            ". . k k k k k k k k k k k k . .",
            ". . . . k sk1 sk1 sk1 sk0 k . .",
            ". . . . k sk1 k sk1 k sk0 k . .",
            ". . . . k sk1 sk1 sk1 sk0 k . .",
            ". . . . . k k k k k k . . . . .",
            ". . . . k r2 r1 ov1 ov1 r1 k . .",
            ". . . . k r1 r1 ov1 ov0 r0 sk1 k",
            ". . . . . k ov1 ov1 y1 ov0 sk0 k",
            ". . . . . k ov1 ov0 ov0 k k k .",
            ". . . . . k ov0 k k ov0 k . . .",
            ". . . . . k ov0 k k ov0 k . . .",
            ". . . . . k b1 k . k b0 k . . .",
            ". . . . . k k k . . k k k . . .",
            ". . . . . . . . . . . . . . . .",
            ". . . . . . . . . . . . . . . .",
        ]
    sprite = parse_sprite(lines, w, h)
    stamp(px, w, 0, 0, sprite, w, h, alpha_blend=True)
    return px


def make_cloud_shadow_variant(variant):
    """
    Generates a single 64x32 pixel-art cumulus cloud silhouette with UNIFORM opacity
    (no overlapping circle seams!) and a subtle softer 1px outer fringe.
    """
    w, h = 64, 32
    # Define organic cumulus silhouettes as union of ellipses (flat base, billowy puffs on top)
    if variant == 0:
        # Classic broad cumulus
        blobs = [
            (32.0, 20.0, 24.0, 6.5),
            (20.0, 17.5, 11.5, 7.0),
            (31.0, 13.0, 13.0, 9.0),
            (44.0, 17.0, 10.5, 6.8),
            (13.0, 20.5, 7.5, 4.5),
            (51.0, 20.5, 7.0, 4.2),
        ]
    elif variant == 1:
        # Tall twin-puff cumulus
        blobs = [
            (32.0, 21.0, 20.0, 5.8),
            (23.0, 14.5, 11.0, 8.2),
            (38.0, 15.5, 12.0, 8.5),
            (49.0, 20.0, 8.0, 4.8),
            (15.0, 20.0, 7.5, 4.5),
        ]
    else:
        # Elongated breezy drift cloud
        blobs = [
            (32.0, 19.5, 25.0, 5.2),
            (18.0, 16.5, 9.5, 5.8),
            (30.0, 14.5, 11.5, 6.5),
            (43.0, 16.5, 10.0, 5.5),
            (53.0, 19.5, 6.5, 3.8),
        ]

    # Compute binary union mask on a 2x2 pixel-art grid (chunky crisp 2px steps!)
    mask = [[0] * w for _ in range(h)]
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            cx_p = x + 0.5
            cy_p = y + 0.5
            inside = False
            for (bx, by, rx, ry) in blobs:
                dx = (cx_p - bx) / rx
                dy = (cy_p - by) / ry
                if dx * dx + dy * dy <= 1.0:
                    inside = True
                    break
            # Flatten underside gently for authentic cumulus base
            if inside and cy_p > 24.5:
                inside = False
            if inside:
                for dy2 in range(2):
                    for dx2 in range(2):
                        if y + dy2 < h and x + dx2 < w:
                            mask[y + dy2][x + dx2] = 1

    # Build uniform-alpha silhouette with soft 1-step rim (NO internal overlap!)
    px = new_canvas(w, h, (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            if mask[y][x] == 1:
                # Check if edge pixel (any 4-neighbor outside)
                is_edge = (
                    x == 0 or x == w - 1 or y == 0 or y == h - 1
                    or mask[y - 1][x] == 0 or mask[y + 1][x] == 0
                    or mask[y][x - 1] == 0 or mask[y][x + 1] == 0
                )
                alpha = 145 if is_edge else 255
                px[y * w + x] = (18, 28, 46, alpha)
    return px


def generate_all():
    # 1. field_atlas.png (8 cols x 3 rows of 16x16 = 128 x 48)
    # Row 0: 4 organic grass variants + 4 inner-corner grass bevel patches (NW, NE, SW, SE)
    # Row 1: status icons (drop, frost, heat, sparkle, highlight, fertilized overlay)
    # Row 2: tool icons (spade, rake, water, inspect)
    aw, ah = 8 * 16, 3 * 16
    atlas = new_canvas(aw, ah)
    for v in range(4):
        stamp(atlas, aw, v * 16, 0, make_organic_grass(v), 16, 16)
    for c_idx in range(4):
        stamp(atlas, aw, (4 + c_idx) * 16, 0, make_inner_corner_patch(c_idx), 16, 16)

    for i, icon in enumerate(["drop", "frost", "heat", "sparkle", "highlight"]):
        stamp(atlas, aw, i * 16, 16, make_status_icon(icon), 16, 16)
    stamp(atlas, aw, 5 * 16, 16, make_fertilized_overlay(), 16, 16)
    for i, tool in enumerate(["spade", "rake", "water", "inspect"]):
        stamp(atlas, aw, i * 16, 32, make_tool_icon(tool), 16, 16)
    write_png(os.path.join(TILES_DIR, "field_atlas.png"), aw, ah, atlas)

    # 2. soil_autotile.png (16 cols x 5 rows of 16x16 = 256 x 80)
    # Row 0: vangato dry
    # Row 1: vangato wet
    # Row 2: rastrellato dry
    # Row 3: rastrellato wet
    # Row 4: rastrellato waterlogged
    sw, sh = 16 * 16, 5 * 16
    soil_atlas = new_canvas(sw, sh)
    rows_cfg = [
        ("vangato", False, False),
        ("vangato", True, False),
        ("rastrellato", False, False),
        ("rastrellato", True, False),
        ("rastrellato", True, True),
    ]
    for r_idx, (st_name, is_wet, is_wl) in enumerate(rows_cfg):
        for mask in range(16):
            cell_px = make_soil_autotile_cell(mask, st_name, is_wet, is_wl)
            stamp(soil_atlas, sw, mask * 16, r_idx * 16, cell_px, 16, 16)
    write_png(os.path.join(TILES_DIR, "soil_autotile.png"), sw, sh, soil_atlas)

    # 3. crops_atlas.png (6 cols x 5 rows of 16x20 = 96 x 100)
    cw, ch = 6 * 16, 5 * 20
    crops_atlas = new_canvas(cw, ch)
    crop_ids = ["ravanello", "pomodoro", "cavolo_verza", "piselli", "trifoglio"]
    for r_idx, cid in enumerate(crop_ids):
        for st in range(6):
            c_px = make_crop_3d(cid, st)
            stamp(crops_atlas, cw, st * 16, r_idx * 20, c_px, 16, 20)
    write_png(os.path.join(TILES_DIR, "crops_atlas.png"), cw, ch, crops_atlas)

    # 3b. cloud_shadows.png (3 cumulus silhouettes x 64x32 = 192 x 32)
    clw, clh = 3 * 64, 32
    clouds_atlas = new_canvas(clw, clh)
    for v_idx in range(3):
        stamp(clouds_atlas, clw, v_idx * 64, 0, make_cloud_shadow_variant(v_idx), 64, 32)
    write_png(os.path.join(TILES_DIR, "cloud_shadows.png"), clw, clh, clouds_atlas)

    # 3b. Legacy fallback farmer_sheet.png (only if generate_farmer_sheet.py is absent)
    if not os.path.exists(os.path.join(ROOT, "tools", "generate_farmer_sheet.py")):
        fw, fh = 4 * 16, 22
        farmer_sheet = new_canvas(fw, fh)
        for f_idx in range(4):
            stamp(farmer_sheet, fw, f_idx * 16, 0, make_farmer_frame(f_idx), 16, 22)
        write_png(os.path.join(TILES_DIR, "farmer_sheet.png"), fw, fh, farmer_sheet)

    # 4. Individual UI icons (16x16, crop icons cropped from bottom 16x16 or centered)
    for name, tile in [
        ("icon_spade.png", make_tool_icon("spade")),
        ("icon_rake.png", make_tool_icon("rake")),
        ("icon_water.png", make_tool_icon("water")),
        ("icon_inspect.png", make_tool_icon("inspect")),
        ("icon_compost.png", make_tool_icon("compost")),
        ("icon_probe.png", make_tool_icon("probe")),
    ]:
        write_png(os.path.join(UI_DIR, name), 16, 16, tile)

    for cid in crop_ids:
        full = make_crop_3d(cid, 4)
        # Take rows 1..17 so full crop fits cleanly inside 16x16 UI icon
        cropped = full[1 * 16 : 17 * 16]
        write_png(os.path.join(UI_DIR, f"icon_{cid}.png"), 16, 16, cropped)

    # 5. Generate zoomed 6x visual QA mockup showing connected rounded beds + 3D crops!
    mw, mh = 10 * 16, 8 * 16
    mock = new_canvas(mw, mh)
    # Fill meadow grass
    for gy in range(8):
        for gx in range(10):
            v = (gx * 7 + gy * 13) % 4
            stamp(mock, mw, gx * 16, gy * 16, make_organic_grass(v), 16, 16)

    # Define two connected beds:
    # Top-left L-shaped moist bed (rows 1..3, cols 1..4 + row 3 cols 5..6)
    # Right dry vangato/rastrellato bed (rows 1..3, cols 7..8)
    # Bottom bed (rows 5..6, cols 1..8)
    bed_cells = set()
    for y in range(1, 4):
        for x in range(1, 5):
            bed_cells.add((x, y))
    for x in range(5, 7):
        bed_cells.add((x, 3))
    for y in range(5, 7):
        for x in range(1, 9):
            bed_cells.add((x, y))
    # Also one single isolated tile at (8, 2) to inspect all-rounded 1x1!
    bed_cells.add((8, 2))

    for (gx, gy) in bed_cells:
        mask = 0
        if (gx, gy - 1) in bed_cells: mask |= 1
        if (gx + 1, gy) in bed_cells: mask |= 2
        if (gx, gy + 1) in bed_cells: mask |= 4
        if (gx - 1, gy) in bed_cells: mask |= 8
        wet = gy <= 3
        st_name = "vangato" if (gx >= 6 and gy >= 5) else "rastrellato"
        wl = (gx == 1 and gy == 1)
        tile = make_soil_autotile_cell(mask, st_name, wet=wet, waterlogged=wl)
        stamp(mock, mw, gx * 16, gy * 16, tile, 16, 16, alpha_blend=True)
        # Inner corner bevels
        if (mask & 1) and (mask & 8) and (gx - 1, gy - 1) not in bed_cells:
            stamp(mock, mw, gx * 16, gy * 16, make_inner_corner_patch(0), 16, 16, alpha_blend=True)
        if (mask & 1) and (mask & 2) and (gx + 1, gy - 1) not in bed_cells:
            stamp(mock, mw, gx * 16, gy * 16, make_inner_corner_patch(1), 16, 16, alpha_blend=True)
        if (mask & 4) and (mask & 8) and (gx - 1, gy + 1) not in bed_cells:
            stamp(mock, mw, gx * 16, gy * 16, make_inner_corner_patch(2), 16, 16, alpha_blend=True)
        if (mask & 4) and (mask & 2) and (gx + 1, gy + 1) not in bed_cells:
            stamp(mock, mw, gx * 16, gy * 16, make_inner_corner_patch(3), 16, 16, alpha_blend=True)

    # Plant crops row-by-row (Y-sorted) with 4px upward overhang!
    demo_crops = [
        (1, 2, "pomodoro", 4), (2, 2, "pomodoro", 4), (3, 2, "pomodoro", 3), (4, 2, "pomodoro", 2),
        (1, 3, "pomodoro", 4), (2, 3, "pomodoro", 4), (3, 3, "ravanello", 4), (4, 3, "ravanello", 4),
        (5, 3, "ravanello", 3), (6, 3, "ravanello", 1),
        (1, 5, "cavolo_verza", 4), (2, 5, "cavolo_verza", 4), (3, 5, "cavolo_verza", 3), (4, 5, "cavolo_verza", 2),
        (1, 6, "cavolo_verza", 4), (2, 6, "cavolo_verza", 4), (3, 6, "cavolo_verza", 4), (4, 6, "ravanello", 4),
    ]
    for (gx, gy, cid, st) in sorted(demo_crops, key=lambda item: item[1]):
        c_px = make_crop_3d(cid, st)
        stamp(mock, mw, gx * 16, gy * 16 - 4, c_px, 16, 20, alpha_blend=True)

    # Scale 5x for visual QA
    scale = 5
    pw, ph = mw * scale, mh * scale
    prev = new_canvas(pw, ph)
    for y in range(mh):
        for x in range(mw):
            col = mock[y * mw + x]
            for sy in range(scale):
                for sx in range(scale):
                    prev[(y * scale + sy) * pw + (x * scale + sx)] = col
    write_png(os.path.join(PREVIEW_DIR, "v01_visual_qa.png"), pw, ph, prev)


def write_wav_samples(path, samples, sample_rate=22050):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        data = bytearray()
        for s in samples:
            val = max(-32767, min(32767, int(s * 32767)))
            data.extend(struct.pack("<h", val))
        wf.writeframes(bytes(data))


def generate_audio():
    sr = 22050
    rng = random.Random(7)
    # Only regenerate if missing
    if os.path.exists(os.path.join(AUDIO_DIR, "sfx_spade.wav")):
        return
    spade = [
        (math.sin(2 * math.pi * (140 - 60 * (i / sr)) * (i / sr)) * 0.5 + (rng.random() * 2 - 1) * 0.35)
        * math.exp(-(i / sr) * 28.0) * 0.55
        for i in range(int(sr * 0.14))
    ]
    write_wav_samples(os.path.join(AUDIO_DIR, "sfx_spade.wav"), spade, sr)


if __name__ == "__main__":
    generate_all()
    generate_audio()
    print("Generated upgraded rounded autotile + 3D crop assets!")
