#!/usr/bin/env python3
"""Generate opaque 1024x1024 RGB AppIcon for CleanShield (净盾)."""

from __future__ import annotations

import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ICON_DIR = ROOT / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
ICON_DIR.mkdir(parents=True, exist_ok=True)


def main() -> None:
    size = 1024
    # Deep emerald-slate radial gradient background (100% opaque RGB)
    img = Image.new("RGB", (size, size), (8, 26, 28))
    px = img.load()
    cx, cy = size * 0.5, size * 0.42
    for y in range(size):
        for x in range(size):
            dist = math.hypot(x - cx, y - cy) / (size * 0.78)
            t = min(1.0, dist)
            r = int(14 * (1 - t) + 6 * t)
            g = int(86 * (1 - t) + 20 * t)
            b = int(68 * (1 - t) + 28 * t)
            px[x, y] = (r, g, b)

    # Subtle glowing halo layer
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse((190, 150, 834, 794), fill=(26, 224, 158, 70))
    glow = glow.filter(ImageFilter.GaussianBlur(85))
    img = Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB")

    overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # Concentric radar rings symbolizing blocked ad/tracker waves
    for rad, alpha in [(390, 26), (320, 38)]:
        draw.ellipse(
            (512 - rad, 505 - rad, 512 + rad, 505 + rad),
            outline=(80, 245, 188, alpha),
            width=4,
        )

    # Shield polygon (smooth geometric crest)
    def shield_points(scale: float, dy: float = 0.0) -> list[tuple[float, float]]:
        pts = []
        # Top arch left-to-right
        pts.append((512 - 270 * scale, 245 + dy))
        pts.append((512, 182 + dy))
        pts.append((512 + 270 * scale, 245 + dy))
        # Right curve down to tip
        for i in range(1, 25):
            u = i / 24.0
            ang = u * (math.pi / 2)
            x = 512 + 270 * scale * math.cos(ang * 0.92) * (1 - 0.18 * u)
            y = (245 + dy) + (615 * scale) * (u ** 0.94)
            pts.append((x, y))
        pts.append((512, 245 + dy + 635 * scale))
        # Left curve up from tip
        for i in range(24, 0, -1):
            u = i / 24.0
            ang = u * (math.pi / 2)
            x = 512 - 270 * scale * math.cos(ang * 0.92) * (1 - 0.18 * u)
            y = (245 + dy) + (615 * scale) * (u ** 0.94)
            pts.append((x, y))
        return pts

    # Outer bright mint-emerald shield
    outer = shield_points(1.0, 0)
    draw.polygon(outer, fill=(24, 212, 148, 255))

    # Inner dark-jade shield core
    inner = shield_points(0.86, 36)
    draw.polygon(inner, fill=(10, 48, 44, 255))

    # Bold crisp white-mint checkmark + slash-ad spark inside shield
    check_pts = [
        (392, 525),
        (476, 608),
        (648, 422),
    ]
    draw.line(check_pts, fill=(82, 252, 190, 255), width=62, joint="curve")
    for x, y in check_pts:
        draw.ellipse((x - 31, y - 31, x + 31, y + 31), fill=(82, 252, 190, 255))

    # Small glowing star/sparkle top-right inside shield symbolizing "clean"
    sx, sy = 640, 326
    draw.polygon([(sx, sy - 28), (sx + 8, sy - 8), (sx + 28, sy), (sx + 8, sy + 8), (sx, sy + 28), (sx - 8, sy + 8), (sx - 28, sy), (sx - 8, sy - 8)], fill=(255, 255, 255, 235))

    final_rgb = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    out_png = ICON_DIR / "AppIcon-1024.png"
    final_rgb.save(out_png, format="PNG")

    contents = {
        "images": [
            {
                "filename": "AppIcon-1024.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
            }
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (ICON_DIR / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")
    print(f"Generated opaque RGB AppIcon at {out_png} ({final_rgb.size}, mode={final_rgb.mode})")


if __name__ == "__main__":
    main()
