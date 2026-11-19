#!/usr/bin/env python3
"""Generate crisp 2048x2732 opaque RGB iPad Pro 13-inch (APP_IPAD_PRO_3GEN_129) screenshots
for CleanShield (zh-Hans & en-US) reusing captured simulator screens.
"""

from __future__ import annotations

import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_media_pack as g  # noqa: E402

APPSTORE_DIR = Path("/Users/wang/OPC/media/20261119-clean-shield/appstore")
IPAD_DIR = APPSTORE_DIR / "ipad"


def extract_phone_ui(board_path: Path) -> Image.Image:
    im = Image.open(board_path).convert("RGB")
    # In render_appstore_board: W=1284, phone_w=1020 at px=132, py=540
    # Crop bezel + screen cleanly
    return im.crop((110, 520, 1174, 2745))


def render_ipad_board(
    ui_left: Image.Image,
    ui_right: Image.Image,
    badge: str,
    headline: str,
    sub: str,
    out_path: Path,
) -> None:
    W, H = 2048, 2732
    bg = g.make_gradient_bg(W, H).convert("RGBA")
    draw = ImageDraw.Draw(bg)

    f_badge = g.load_font(48, 1)
    f_h1 = g.load_font(94, 1)
    f_sub = g.load_font(48, 0)

    bbox = draw.textbbox((0, 0), badge, font=f_badge)
    bw = (bbox[2] - bbox[0]) + 84
    bx = (W - bw) // 2
    draw.rounded_rectangle((bx, 115, bx + bw, 205), radius=45, fill=(14, 72, 58, 255), outline=(82, 250, 190, 220), width=4)
    draw.text((W // 2, 160), badge, font=f_badge, fill=(110, 255, 202), anchor="mm")

    draw.text((W // 2, 315), headline, font=f_h1, fill=(255, 255, 255), anchor="mm")
    draw.text((W // 2, 425), sub, font=f_sub, fill=(180, 212, 202), anchor="mm")

    # Tablet-style showcase frame containing dual side-by-side live screens
    card_w, card_h = 1820, 2040
    cx0, cy0 = (W - card_w) // 2, 540
    draw.rounded_rectangle(
        (cx0, cy0, cx0 + card_w, cy0 + card_h),
        radius=76,
        fill=(11, 24, 26, 255),
        outline=(58, 242, 178, 130),
        width=5,
    )

    pane_w = 815
    pane_h = int(ui_left.height * (pane_w / ui_left.width))
    # Fit inside card vertically if needed
    max_pane_h = card_h - 110
    if pane_h > max_pane_h:
        pane_h = max_pane_h
        pane_w = int(ui_left.width * (pane_h / ui_left.height))

    l_res = g.round_corners(ui_left.resize((pane_w, pane_h), Image.Resampling.LANCZOS), 64)
    r_res = g.round_corners(ui_right.resize((pane_w, pane_h), Image.Resampling.LANCZOS), 64)

    gap = 64
    total_w = pane_w * 2 + gap
    lx = (W - total_w) // 2
    rx = lx + pane_w + gap
    py = cy0 + (card_h - pane_h) // 2

    bg.alpha_composite(l_res, (lx, py))
    bg.alpha_composite(r_res, (rx, py))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    bg.convert("RGB").save(out_path, format="PNG")


def main() -> None:
    zh_u1 = extract_phone_ui(APPSTORE_DIR / "zh-Hans" / "01-audit.png")
    zh_u2 = extract_phone_ui(APPSTORE_DIR / "zh-Hans" / "02-safari.png")
    zh_u3 = extract_phone_ui(APPSTORE_DIR / "zh-Hans" / "03-tools.png")
    zh_u4 = extract_phone_ui(APPSTORE_DIR / "zh-Hans" / "04-pro.png")

    render_ipad_board(
        zh_u1, zh_u2,
        "100% 纯本地离线 · 零密码权限 · 绝不断网",
        "30 项深藏开关关停 + Safari 零权限净盾",
        "根治摇一摇乱跳购物页 · 内置高德地图/四大行/10086 免误杀铁白名单",
        IPAD_DIR / "zh-Hans" / "01-ipad-audit-safari.png",
    )
    render_ipad_board(
        zh_u3, zh_u4,
        "发原图前抹除 GPS · 一杯奶茶钱永久买断",
        "照片定位隐私抹除 + 桌面一步直达组件",
        "纯本地内存剥离精确经纬度与机型参数 · 核心防护永久免费",
        IPAD_DIR / "zh-Hans" / "02-ipad-tools-pro.png",
    )
    render_ipad_board(
        zh_u2, zh_u3,
        "含微信 180 天开关失效自动复检提醒",
        "一次配置 · 告别半年后定向广告悄悄复活",
        "支持家庭共享 · 100% 纯本地运算绝不上传任何网页或相册记录",
        IPAD_DIR / "zh-Hans" / "03-ipad-privacy.png",
    )

    en_u1 = extract_phone_ui(APPSTORE_DIR / "en-US" / "01-audit.png")
    en_u2 = extract_phone_ui(APPSTORE_DIR / "en-US" / "02-safari.png")
    en_u3 = extract_phone_ui(APPSTORE_DIR / "en-US" / "03-tools.png")
    en_u4 = extract_phone_ui(APPSTORE_DIR / "en-US" / "04-pro.png")

    render_ipad_board(
        en_u1, en_u2,
        "100% ON-DEVICE · NO PASSWORD PERMISSION",
        "30-Point Ad Switch Audit + Safari Web Shield",
        "Stop motion-sensor redirects & protect Maps, Banks & Carriers with Safe Whitelist",
        IPAD_DIR / "en-US" / "01-ipad-audit-safari.png",
    )
    render_ipad_board(
        en_u3, en_u4,
        "ZERO CLOUD UPLOAD · HONEST LIFETIME OPTION",
        "Photo GPS Scrubber + Clean Direct Launch",
        "Strip hidden latitude/longitude before sharing · Core protection free forever",
        IPAD_DIR / "en-US" / "02-ipad-tools-pro.png",
    )
    render_ipad_board(
        en_u2, en_u3,
        "180-DAY SILENT RESET REMINDERS INCLUDED",
        "Built for Privacy Without Breaking Daily Apps",
        "Family Sharing supported · Native StoreKit 2 · Zero analytics or trackers",
        IPAD_DIR / "en-US" / "03-ipad-privacy.png",
    )
    print(f"Generated 6 iPad 13-inch screenshots in {IPAD_DIR}")


if __name__ == "__main__":
    main()
