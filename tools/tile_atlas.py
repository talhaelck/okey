"""Generates the okey tile face atlas: albedo + OpenGL-style normal map with engraved, paint-filled numbers.

    python tools/tile_atlas.py [out_dir]   (default: assets/textures/tiles)

Layout: 8 columns x 7 rows of cells; cell index = colour * 13 + (number - 1) for colours 0..3
(red, black, blue, yellow), 52 = fake okey, 53 = blank. Must match TileFactory.cell() and tile.gdshader.
Needs Pillow + numpy and the Windows Arial Black font; the output PNGs are committed, so the game does not.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

COLS, ROWS = 8, 7
CELL_W, CELL_H = 200, 292  # same aspect as the tile face (0.048 x 0.07 m)
IVORY = np.array([236, 228, 208], dtype=np.float32)
INK = [(196, 32, 38), (28, 28, 32), (24, 92, 196), (228, 146, 12), (34, 132, 68)]
FONT = "C:/Windows/Fonts/ariblk.ttf"
ENGRAVE_DEPTH = 1.0
NORMAL_STRENGTH = 3.0

rng = np.random.default_rng(7)


def cell_origin(index):
    return (index % COLS) * CELL_W, (index // COLS) * CELL_H


def star(cx, cy, outer, inner):
    pts = []
    for i in range(10):
        r = outer if i % 2 == 0 else inner
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def draw_mask(index):
    """White where the face is engraved and painted, black elsewhere (one cell)."""
    mask = Image.new("L", (CELL_W, CELL_H), 0)
    d = ImageDraw.Draw(mask)
    if index == 52:
        d.polygon(star(CELL_W / 2, CELL_H * 0.47, CELL_W * 0.36, CELL_W * 0.15), fill=255)
    elif index < 52:
        number = index % 13 + 1
        text = str(number)
        size = 150 if number < 10 else 118
        font = ImageFont.truetype(FONT, size)
        box = d.textbbox((0, 0), text, font=font)
        w, h = box[2] - box[0], box[3] - box[1]
        d.text(((CELL_W - w) / 2 - box[0], CELL_H * 0.4 - h / 2 - box[1]), text, font=font, fill=255)
        r = 15
        cx, cy = CELL_W / 2, CELL_H * 0.78
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    return mask


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "tiles")
    os.makedirs(out, exist_ok=True)
    width, height = COLS * CELL_W, ROWS * CELL_H
    albedo = np.zeros((height, width, 3), dtype=np.float32)
    heightmap = np.zeros((height, width), dtype=np.float32)

    for index in range(COLS * ROWS):
        x0, y0 = cell_origin(index)
        mask_img = draw_mask(index)
        # Soft engraving walls: blur the mask a little for the height, keep it crisp for the paint.
        paint = np.asarray(mask_img, dtype=np.float32) / 255.0
        engrave = np.asarray(mask_img.filter(ImageFilter.GaussianBlur(2.2)), dtype=np.float32) / 255.0
        ink = np.array(INK[4 if index == 52 else (index // 13 if index < 52 else 0)], dtype=np.float32)

        # Ivory with faint marbling, darker toward the cell edges where the face curves into the bevel.
        noise = np.asarray(Image.fromarray((rng.random((CELL_H // 8, CELL_W // 8)) * 255).astype(np.uint8))
                           .resize((CELL_W, CELL_H), Image.BICUBIC), dtype=np.float32) / 255.0
        yy, xx = np.mgrid[0:CELL_H, 0:CELL_W]
        edge = np.minimum(np.minimum(xx, CELL_W - 1 - xx) / CELL_W, np.minimum(yy, CELL_H - 1 - yy) / CELL_H)
        shade = 0.93 + 0.07 * np.clip(edge * 12.0, 0, 1)
        base = IVORY[None, None, :] * (0.975 + 0.03 * noise[..., None]) * shade[..., None]

        # Paint inside the engraving, slightly worn: a few lighter flecks where the paint chipped.
        wear = rng.random((CELL_H, CELL_W)) < 0.012
        paint_amount = paint * np.where(wear, 0.45, 1.0)
        cell = base * (1.0 - paint_amount[..., None]) + ink[None, None, :] * (0.92 + 0.08 * noise[..., None]) * paint_amount[..., None]
        # Tiny dirt specks on the ivory.
        specks = rng.random((CELL_H, CELL_W)) < 0.0015
        cell[specks] *= 0.82

        albedo[y0:y0 + CELL_H, x0:x0 + CELL_W] = cell
        heightmap[y0:y0 + CELL_H, x0:x0 + CELL_W] = -engrave * ENGRAVE_DEPTH + (noise - 0.5) * 0.04

    # Tangent-space normal map, OpenGL convention (green = up), as Godot expects.
    gy_img, gx = np.gradient(heightmap)
    n = np.stack([-gx * NORMAL_STRENGTH, gy_img * NORMAL_STRENGTH, np.ones_like(heightmap)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    normal = ((n * 0.5 + 0.5) * 255).astype(np.uint8)

    Image.fromarray(np.clip(albedo, 0, 255).astype(np.uint8)).save(os.path.join(out, "tile_albedo.png"))
    Image.fromarray(normal).save(os.path.join(out, "tile_normal.png"))
    print("atlas", width, "x", height, "->", os.path.abspath(out))


main()
