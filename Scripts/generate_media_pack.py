#!/usr/bin/env python3
"""Capture real iOS Simulator UI screenshots of CleanShield (zh & en) and render:
1) Apple App Store 6.5" (1284x2778 opaque RGB) screenshots for zh-Hans & en-US
2) Xiaohongshu 3:4 (1200x1600) viral carousel cards
3) Xianyu 1:1 (1200x1200) lazy-kit cards
Automatically cleans up temporary raw captures upon completion.
"""

from __future__ import annotations

import math
import shutil
import subprocess
import tempfile
import time
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

SIM_ID = "3D895598-84D1-4930-8B8A-11FDA9816557"
BUNDLE_ID = "com.yanghe.cleanshield"
APP_BUNDLE = Path("/Users/wang/OPC/projects/clean-shield/DerivedData/Build/Products/Debug-iphonesimulator/CleanShield.app")
MEDIA_ROOT = Path("/Users/wang/OPC/media/20261119-clean-shield")
RELEASE_DIR = Path("/Users/wang/OPC/projects/clean-shield/release")

FONT_CANDIDATES = [
    "/System/Library/AssetsV2/com_apple_MobileAsset_Font8/86ba2c91f017a3749571a82f2c6d890ac7ffb2fb.asset/AssetData/PingFang.ttc",
    "/System/Library/Fonts/STHeiti Medium.ttc",
    "/System/Library/PrivateFrameworks/FontServices.framework/Versions/A/Resources/Reserved/PingFangUI.ttc",
]


def load_font(size: int, index: int = 0) -> ImageFont.FreeTypeFont:
    # In PingFang.ttc: index 3 = PingFang SC Regular, index 11 = PingFang SC Semibold
    sc_index = 11 if index >= 1 else 3
    for fp in FONT_CANDIDATES:
        if Path(fp).exists():
            try:
                return ImageFont.truetype(fp, size, index=sc_index)
            except Exception:
                try:
                    return ImageFont.truetype(fp, size, index=0)
                except Exception:
                    pass
    return ImageFont.load_default()


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def capture_sim_screens(tmp_dir: Path) -> dict[str, Path]:
    run(["xcrun", "simctl", "boot", SIM_ID])
    time.sleep(2.0)
    run(["xcrun", "simctl", "ui", SIM_ID, "appearance", "dark"])
    run([
        "xcrun", "simctl", "status_bar", SIM_ID, "override",
        "--time", "9:41",
        "--batteryState", "charged",
        "--batteryLevel", "100",
        "--cellularMode", "active",
        "--cellularBars", "4",
        "--wifiBars", "3",
    ])
    run(["xcrun", "simctl", "install", SIM_ID, str(APP_BUNDLE)])

    shots: dict[str, Path] = {}
    specs = [
        ("zh_01", ["--lang", "zh", "--tab", "0", "--demo-progress"]),
        ("zh_02", ["--lang", "zh", "--tab", "1", "--demo-progress"]),
        ("zh_03", ["--lang", "zh", "--tab", "2", "--demo-progress"]),
        ("zh_04", ["--lang", "zh", "--tab", "0", "--demo-progress", "--show-paywall"]),
        ("en_01", ["--lang", "en", "--tab", "0", "--demo-progress"]),
        ("en_02", ["--lang", "en", "--tab", "1", "--demo-progress"]),
        ("en_03", ["--lang", "en", "--tab", "2", "--demo-progress"]),
        ("en_04", ["--lang", "en", "--tab", "0", "--demo-progress", "--show-paywall"]),
    ]

    # Warm up simulator launch once so subsequent launches skip cold shader/font compilation
    run(["xcrun", "simctl", "launch", SIM_ID, BUNDLE_ID, "--lang", "zh", "--tab", "0", "--demo-progress"])
    time.sleep(4.5)

    for key, args in specs:
        run(["xcrun", "simctl", "terminate", SIM_ID, BUNDLE_ID])
        time.sleep(0.5)
        run(["xcrun", "simctl", "launch", SIM_ID, BUNDLE_ID] + args)
        time.sleep(4.2)
        out_p = tmp_dir / f"{key}.png"
        run(["xcrun", "simctl", "io", SIM_ID, "screenshot", str(out_p)])
        shots[key] = out_p
        print(f"  Captured simulator screen: {key}")

    run(["xcrun", "simctl", "status_bar", SIM_ID, "clear"])
    return shots


def make_gradient_bg(w: int, h: int, top_rgb=(10, 48, 40), bot_rgb=(7, 18, 24)) -> Image.Image:
    img = Image.new("RGB", (w, h), bot_rgb)
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        r = int(top_rgb[0] * (1 - t) + bot_rgb[0] * t)
        g = int(top_rgb[1] * (1 - t) + bot_rgb[1] * t)
        b = int(top_rgb[2] * (1 - t) + bot_rgb[2] * t)
        for x in range(w):
            px[x, y] = (r, g, b)
    return img


def round_corners(im: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", im.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, im.size[0], im.size[1]), radius=radius, fill=255)
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out


def render_appstore_board(raw_shot: Path, badge: str, headline1: str, headline2: str, sub: str, out_path: Path) -> None:
    W, H = 1284, 2778
    bg = make_gradient_bg(W, H).convert("RGBA")
    draw = ImageDraw.Draw(bg)

    f_badge = load_font(38, index=1)
    f_h1 = load_font(74, index=1)
    f_sub = load_font(40, index=0)

    # Pill badge (high-contrast dark emerald fill with bright mint text)
    bbox = draw.textbbox((0, 0), badge, font=f_badge)
    bw = (bbox[2] - bbox[0]) + 68
    bx = (W - bw) // 2
    draw.rounded_rectangle((bx, 110, bx + bw, 184), radius=37, fill=(14, 72, 58, 255), outline=(82, 250, 190, 220), width=3)
    draw.text((W // 2, 147), badge, font=f_badge, fill=(110, 255, 202), anchor="mm")

    draw.text((W // 2, 265), headline1, font=f_h1, fill=(255, 255, 255), anchor="mm")
    draw.text((W // 2, 360), headline2, font=f_h1, fill=(82, 250, 190), anchor="mm")
    draw.text((W // 2, 452), sub, font=f_sub, fill=(180, 212, 202), anchor="mm")

    # Device frame bezel + real simulator UI screenshot
    phone_w = 1020
    raw = Image.open(raw_shot).convert("RGB")
    phone_h = int(raw.height * (phone_w / raw.width))
    resized = raw.resize((phone_w, phone_h), Image.Resampling.LANCZOS)
    rounded = round_corners(resized, radius=92)

    px = (W - phone_w) // 2
    py = 540
    # Outer metallic bezel
    draw.rounded_rectangle((px - 18, py - 18, px + phone_w + 18, py + phone_h + 18), radius=108, fill=(22, 38, 40), outline=(82, 250, 190, 110), width=4)
    bg.alpha_composite(rounded, (px, py))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    bg.convert("RGB").save(out_path, format="PNG")


def render_xhs_and_xianyu(shots: dict[str, Path]) -> None:
    RELEASE_DIR.mkdir(parents=True, exist_ok=True)
    xhs_media = MEDIA_ROOT / "social"
    xhs_media.mkdir(parents=True, exist_ok=True)

    # 1. XHS Cover 3:4 (1200x1600)
    c1 = make_gradient_bg(1200, 1600, (12, 62, 50), (8, 18, 24)).convert("RGBA")
    d1 = ImageDraw.Draw(c1)
    d1.rounded_rectangle((68, 64, 520, 130), radius=33, fill=(255, 92, 108, 235))
    d1.text((294, 97), "90%的人没关这4个开关！", font=load_font(34, 1), fill=(255, 255, 255), anchor="mm")
    d1.text((68, 175), "走路晃一下就跳购物页？", font=load_font(68, 1), fill=(255, 255, 255))
    d1.text((68, 268), "刚聊完啥手机马上推啥？", font=load_font(68, 1), fill=(82, 250, 190))
    d1.text((68, 368), "苹果+小米+华为+OV 隐藏关停路线全整理 · 纯离线零隐私上传", font=load_font(32, 0), fill=(195, 224, 215))

    s_img = Image.open(shots["zh_01"]).convert("RGB").resize((680, 1475), Image.Resampling.LANCZOS)
    s_rnd = round_corners(s_img, 64)
    d1.rounded_rectangle((248, 448, 952, 1560), radius=76, fill=(20, 36, 38), outline=(82, 250, 190, 140), width=4)
    c1.alpha_composite(s_rnd, (260, 460))
    for p in [RELEASE_DIR / "xhs-01-cover.png", xhs_media / "xhs-01-cover.png"]:
        c1.convert("RGB").save(p, format="PNG")

    # 2. XHS Card 2: 摇一摇物理断电速查 (1200x1600)
    c2 = make_gradient_bg(1200, 1600, (14, 44, 54), (8, 16, 22))
    d2 = ImageDraw.Draw(c2)
    d2.text((70, 80), "第 1 招：物理废掉「开屏摇一摇」", font=load_font(56, 1), fill=(82, 250, 190))
    d2.text((70, 162), "切断陀螺仪权限后，就算画面还在，甩着手机跑也绝不乱跳！", font=load_font(32, 0), fill=(210, 230, 225))
    rows = [
        ("🍎 苹果 iPhone", "设置 → 隐私与安全性 → 运动与健身 → 关掉购物/资讯软件（或进限制动作数据）"),
        ("🟠 小米澎湃 OS", "设置 → 应用设置 → 授权管理 → 权限 → 获取设备动作与方向 → 设为拒绝"),
        ("🔴 华为鸿蒙 OS", "设置 → 隐私 → 权限管理 → 应用访问设备动作与方向 → 批量关闭"),
        ("🟢 OPPO / 一加", "设置 → 权限与隐私 → 权限管理 → 设备动作与方向 → 不允许"),
        ("🔵 vivo / 荣耀", "设置 → 隐私 → 权限管理 → 访问设备动作与方向 → 批量关闭"),
    ]
    y = 260
    for brand, path_txt in rows:
        d2.rounded_rectangle((65, y, 1135, y + 215), radius=26, fill=(18, 38, 42), outline=(58, 242, 178))
        d2.text((100, y + 34), brand, font=load_font(40, 1), fill=(82, 250, 190))
        d2.text((100, y + 105), path_txt[:31], font=load_font(30, 0), fill=(240, 250, 246))
        if len(path_txt) > 31:
            d2.text((100, y + 150), path_txt[31:], font=load_font(30, 0), fill=(240, 250, 246))
        y += 245
    for p in [RELEASE_DIR / "xhs-02-shake-fix.png", xhs_media / "xhs-02-shake-fix.png"]:
        c2.save(p, format="PNG")

    # 3. XHS Card 3: 微信半年自动复活陷阱 + 发图抹定位 (1200x1600)
    c3 = make_gradient_bg(1200, 1600, (24, 34, 48), (9, 16, 24)).convert("RGBA")
    d3 = ImageDraw.Draw(c3)
    d3.text((70, 80), "第 2 招：小心「每半年自动复活」陷阱！", font=load_font(52, 1), fill=(255, 186, 66))
    d3.text((70, 162), "很多人关过一次精准广告，6 个月后又满屏推同款，因为有效期只有 180 天", font=load_font(30, 0), fill=(215, 228, 235))
    s_img3 = Image.open(shots["zh_03"]).convert("RGB").resize((660, 1430), Image.Resampling.LANCZOS)
    c3.alpha_composite(round_corners(s_img3, 60), (270, 250))
    for p in [RELEASE_DIR / "xhs-03-safari-gps.png", xhs_media / "xhs-03-safari-gps.png"]:
        c3.convert("RGB").save(p, format="PNG")

    # 4. Xianyu 1:1 Cover (1200x1200)
    xy = make_gradient_bg(1200, 1200, (10, 56, 44), (6, 18, 22))
    dx = ImageDraw.Draw(xy)
    dx.rounded_rectangle((60, 60, 1140, 1140), radius=42, outline=(82, 250, 190), width=5)
    dx.rounded_rectangle((100, 110, 560, 182), radius=36, fill=(34, 227, 156))
    dx.text((330, 146), "免Root · 零误杀 · 当天清爽", font=load_font(34, 1), fill=(6, 32, 24), anchor="mm")
    dx.text((100, 235), "手机去广告 & 防摇一摇", font=load_font(74, 1), fill=(255, 255, 255))
    dx.text((100, 340), "全套懒人清净配置包", font=load_font(74, 1), fill=(82, 250, 190))
    bullets = [
        "● 覆盖小米澎湃 / 华为鸿蒙 / OPPO / vivo / 荣耀 / 苹果",
        "● 3 分钟彻底废掉开屏「摇一摇乱跳购物页」",
        "● 30 大软件隐藏监听与个性化广告开关一步一图",
        "● 附加密私人 DNS 零误杀白名单 + 电脑一键停用广告脚本",
        "● 拍下秒发全套离线图文包 + 在线一键寻路工具直链",
    ]
    by = 490
    for b in bullets:
        dx.text((105, by), b, font=load_font(35, 0), fill=(235, 248, 242))
        by += 86
    dx.rounded_rectangle((100, 965, 1100, 1075), radius=24, fill=(255, 180, 36))
    dx.text((600, 1020), "一杯水钱省掉 2 小时到处翻教程 · 小白/长辈机一学就会", font=load_font(34, 1), fill=(28, 18, 4), anchor="mm")
    for p in [RELEASE_DIR / "xianyu-01-cover.png", xhs_media / "xianyu-01-cover.png"]:
        xy.save(p, format="PNG")


def main() -> None:
    tmp_dir = Path(tempfile.mkdtemp(prefix="cleanshield_shots_"))
    try:
        shots = capture_sim_screens(tmp_dir)

        zh_specs = [
            ("zh_01", "100% 纯本地离线 · 零隐私上传", "30 项深藏广告开关", "3 分钟一键找齐关停", "根治走路摇一摇乱跳 · 含微信 180 天复活提醒", "01-audit.png"),
            ("zh_02", "绝不索要「读取网页密码」权限", "Safari 零权限净盾", "内置 26 项免误杀白名单", "拦牛皮癣与追踪器 · 地图/银行/10086 永不断网", "02-safari.png"),
            ("zh_03", "保护家庭住址 · 桌面清爽直达", "发原图前抹除 GPS", "桌面小组件一步扫码", "剥离精确经纬度与机型 · 跳过繁杂推荐信息流", "03-tools.png"),
            ("zh_04", "良心独立开发 · 无套路扣费", "核心防护永久免费", "一杯奶茶钱终身买断", "支持家庭共享 · 一次付清包后续新系统规则更新", "04-pro.png"),
        ]
        for key, badge, h1, h2, sub, fname in zh_specs:
            render_appstore_board(shots[key], badge, h1, h2, sub, MEDIA_ROOT / "appstore" / "zh-Hans" / fname)

        en_specs = [
            ("en_01", "100% ON-DEVICE · ZERO CLOUD UPLOAD", "30 Hidden Ad Switches", "Found & Closed in 3 Min", "Stop shake-to-jump redirects & 180-day silent resets", "01-audit.png"),
            ("en_02", "NO SCARY PASSWORD-READ PERMISSION", "Native Safari Shield", "26-Domain Safe Whitelist", "Blocks banners & spy pixels · Maps & Banks never break", "02-safari.png"),
            ("en_03", "PROTECT YOUR HOME COORDINATES", "1-Tap GPS Scrubber", "& Direct Launch Widgets", "Strip hidden photo EXIF metadata before sharing", "03-tools.png"),
            ("en_04", "HONEST INDIE UTILITY · FAMILY SHARING", "Free Core Protection", "Or Pay Once For Life", "Transparent pricing · Zero tracking · Zero ads", "04-pro.png"),
        ]
        for key, badge, h1, h2, sub, fname in en_specs:
            render_appstore_board(shots[key], badge, h1, h2, sub, MEDIA_ROOT / "appstore" / "en-US" / fname)

        render_xhs_and_xianyu(shots)
        print(f"✅ All App Store (zh-Hans & en-US) and Social media assets generated in {MEDIA_ROOT}")
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)
        print("🧹 Cleaned temporary simulator raw screenshots")


if __name__ == "__main__":
    main()
