"""Generate Calender app icons in lucide-style.

Brand color: #1a73e8.
Icon: a `calendar-days` style glyph (lucide) on a rounded blue tile.
Output:
  web/assets/icon.svg            (favicon, 24x24 viewBox)
  web/assets/icon-192x192.png    (PWA)
  web/assets/icon-512x512.png    (PWA / maskable)
"""

import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "..", "web", "assets")
OUT_DIR = os.path.abspath(OUT_DIR)
os.makedirs(OUT_DIR, exist_ok=True)

BG = (26, 115, 232, 255)   # #1a73e8
FG = (255, 255, 255, 255)  # white

PNG_SIZES = [192, 512]

# 24-unit lucide viewBox, calendar-days variant.
LUCIDE_PATHS = [
    ("rect", (3, 4, 18, 18, 2)),                  # body, rx = 2
    ("line", (3, 10, 21, 10)),                   # header
    ("line", (8, 2, 8, 6)),                      # left binder
    ("line", (16, 2, 16, 6)),                    # right binder
    ("dot", (8, 14)),
    ("dot", (12, 14)),
    ("dot", (16, 14)),
    ("dot", (8, 18)),
    ("dot", (12, 18)),
    ("dot", (16, 18)),
]


def _to_px(coord: float, ox: float, scale: float) -> float:
    return ox + coord * scale


def draw_lucide_calendar(d: ImageDraw.ImageDraw, canvas_size: int) -> None:
    # Rounded blue background tile
    pad = int(canvas_size * 0.04)
    radius = int(canvas_size * 0.22)
    d.rounded_rectangle(
        (pad, pad, canvas_size - pad, canvas_size - pad),
        radius=radius,
        fill=BG,
    )

    # Icon area: ~60% of canvas, centered
    icon_size = canvas_size * 0.60
    scale = icon_size / 24.0
    ox = (canvas_size - 24 * scale) / 2.0
    oy = (canvas_size - 24 * scale) / 2.0
    stroke_w = max(2, int(round(canvas_size * 0.028)))

    def P(x: float, y: float):
        return (ox + x * scale, oy + y * scale)

    for kind, args in LUCIDE_PATHS:
        if kind == "rect":
            x, y, w, h, rx = args
            box = [P(x, y), P(x + w, y + h)]
            d.rounded_rectangle(
                box,
                radius=max(1, int(round(rx * scale))),
                outline=FG,
                width=stroke_w,
            )
        elif kind == "line":
            x1, y1, x2, y2 = args
            d.line([P(x1, y1), P(x2, y2)], fill=FG, width=stroke_w)
        elif kind == "dot":
            x, y = args
            r = max(1, int(round(stroke_w * 0.55)))
            cx, cy = P(x, y)
            d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=FG)


def write_pngs() -> None:
    for size in PNG_SIZES:
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        draw_lucide_calendar(d, size)
        path = os.path.join(OUT_DIR, f"icon-{size}x{size}.png")
        img.save(path, format="PNG", optimize=True)
        print(f"wrote {path} ({size}x{size})")


def write_svg() -> None:
    parts = [
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
        'fill="none" stroke="currentColor" stroke-width="1.6" '
        'stroke-linecap="round" stroke-linejoin="round">',
        '  <rect x="3" y="4" width="18" height="18" rx="2"/>',
        '  <line x1="3" y1="10" x2="21" y2="10"/>',
        '  <line x1="8" y1="2" x2="8" y2="6"/>',
        '  <line x1="16" y1="2" x2="16" y2="6"/>',
        '  <circle cx="8" cy="14" r="0.9" fill="currentColor" stroke="none"/>',
        '  <circle cx="12" cy="14" r="0.9" fill="currentColor" stroke="none"/>',
        '  <circle cx="16" cy="14" r="0.9" fill="currentColor" stroke="none"/>',
        '  <circle cx="8" cy="18" r="0.9" fill="currentColor" stroke="none"/>',
        '  <circle cx="12" cy="18" r="0.9" fill="currentColor" stroke="none"/>',
        '  <circle cx="16" cy="18" r="0.9" fill="currentColor" stroke="none"/>',
        '</svg>',
    ]
    svg = "\n".join(parts) + "\n"
    path = os.path.join(OUT_DIR, "icon.svg")
    with open(path, "w", encoding="utf-8") as f:
        f.write(svg)
    print(f"wrote {path}")


if __name__ == "__main__":
    write_pngs()
    write_svg()
