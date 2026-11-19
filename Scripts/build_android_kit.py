#!/usr/bin/env python3
"""Build docs/downloads/clean-shield-android-kit.zip for Android cross-platform funnel."""

from __future__ import annotations

import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "docs" / "downloads"
OUT_DIR.mkdir(parents=True, exist_ok=True)
ZIP_PATH = OUT_DIR / "clean-shield-android-kit.zip"

GUIDE_MD = """# 🛡️ 净盾 CleanShield · 安卓免 Root 防摇一摇与零误杀清净手册 (2026 实战版)

> 适用机型：小米/Redmi（澎湃 HyperOS / MIUI）、华为（鸿蒙 HarmonyOS）、荣耀（MagicOS）、OPPO/一加/真我（ColorOS）、vivo/iQOO（OriginOS）。
> 安全红线：全程仅使用系统自带权限锁、加密私人 DNS 与官方 ADB 停用命令，**免 Root、不刷机、不破坏保修、零误杀高德地图/银行/运营商**。

---

## 第一步：3 分钟废掉所有 App 开屏「摇一摇 / 扭一扭」跳转（100% 物理生效）

摇一摇广告依赖手机陀螺仪与加速度传感器。直接在系统底层切断权限，哪怕开屏画面还在，你甩着手机跑步也绝对跳不走：

1. **小米 / Redmi（澎湃 HyperOS）**：`设置` → `应用设置` → `授权管理 / 权限管理` → `权限` → `获取设备动作与方向` → 将淘宝、京东、拼多多、百度网盘、微博、知乎、菜鸟等全部设为 **拒绝**。
2. **华为（HarmonyOS）**：`设置` → `隐私` → `权限管理` → `应用访问设备动作与方向`（或 `摇一摇广告管理`）→ 批量关闭购物与资讯类软件。
3. **OPPO / 一加 / 真我（ColorOS）**：`设置` → `权限与隐私` → `权限管理` → `权限` → `设备动作与方向` → 设为 **不允许**。
4. **vivo / iQOO（OriginOS）**：`设置` → `隐私` → `权限管理` → `权限` → `访问设备动作与方向` → 批量关闭。
5. **荣耀（MagicOS）**：`设置` → `隐私` → `权限管理` → `应用访问设备动作与方向` → 批量关闭。

---

## 第二步：免装软件开启安卓原生「加密私人 DNS」（过滤第三方追踪域名）

无需在后台挂耗电 VPN 软件，直接用安卓 9+ 原生内置的 `Private DNS (DoT)`：

1. 打开手机 `设置` → 顶栏搜索 **私人 DNS**（或进入 `连接与共享 / 更多连接设置` → `私人 DNS`）。
2. 选择 **指定私人 DNS 提供商主机名**。
3. 填入知名公共防追踪加密 DNS（二选一）：
   - 国际老牌防广告 DNS：`dns.adguard-dns.com`
   - 纯净防钓鱼安全 DNS：`security.cloudflare-dns.com`
4. **避坑铁律**：如果在个别商场公共 Wi-Fi 登录认证页弹不出来，临时切回「自动」连上 Wi-Fi 后再开即可；日常移动流量与家用 Wi-Fi 零耗电生效。

---

## 第三步：开源无障碍防误触工具安全使用建议（GKD 社区生态）

- 国内主流应用商店均不提供自动点跳过工具。如确需辅助点击，仅建议从开源项目 GitHub 官方仓库获取纯净客户端，**切勿在来路不明的网盘下载带木马的破解修改版 App**。
- 开启无障碍权限时，建议仅勾选极少数高频误触场景，避免影响银行客户端安全检测。

---

## 第四步：高阶电脑 ADB 一键安全停用系统内置广告服务（可选）

包内附带 `debloat-safe-ads.sh`（Mac/Linux）与 `debloat-safe-ads.bat`（Windows）。
仅停用各大国产 ROM 公认纯广告/分析后台包（如小米 `com.miui.systemAdSolution`、OPPO `com.heytap.SpeechAssist` 推广插件等），绝不触碰支付、相机、云服务或通话组件，随时可一行命令恢复。
"""

ADB_SH = """#!/usr/bin/env bash
# CleanShield Safe Android System Ad Service Disabler (No-Root ADB)
# Only disables well-known vendor ad-delivery services; 100% reversible via `pm enable`.
set -u

echo "=== CleanShield Android Safe Ad-Service Disabler ==="
if ! command -v adb >/dev/null 2>&1; then
  echo "[!] adb not found. Install Android Platform Tools first."
  exit 1
fi

adb devices
AD_PACKAGES=(
  "com.miui.systemAdSolution"
  "com.miui.analytics"
  "com.xiaomi.ab"
  "com.huawei.intelligent"
  "com.oppo.ads"
  "com.nearme.statistics.rom"
  "com.vivo.magazine"
)

for pkg in "${AD_PACKAGES[@]}"; do
  echo "-> Attempting safe disable for $pkg ..."
  adb shell pm disable-user --user 0 "$pkg" 2>/dev/null || true
done

echo "=== Done! Reboot phone once for clean state. To restore any package: adb shell pm enable <pkg> ==="
"""

ADB_BAT = """@echo off
echo === CleanShield Android Safe Ad-Service Disabler (Windows) ===
where adb >nul 2>nul
if %errorlevel% neq 0 (
  echo [!] Please extract Android platform-tools (adb.exe) into this folder first.
  pause
  exit /b 1
)
adb devices
for %%p in (
  com.miui.systemAdSolution
  com.miui.analytics
  com.xiaomi.ab
  com.oppo.ads
  com.nearme.statistics.rom
  com.vivo.magazine
) do (
  echo Disabling %%p ...
  adb shell pm disable-user --user 0 %%p
)
echo === Completed! Reboot your phone once. ===
pause
"""


def main() -> None:
    with zipfile.ZipFile(ZIP_PATH, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("01-安卓6大品牌防摇一摇与零误杀清净手册.md", GUIDE_MD)
        zf.writestr("02-Mac_Linux免Root停用系统广告服务.sh", ADB_SH)
        zf.writestr("03-Windows免Root停用系统广告服务.bat", ADB_BAT)
    print(f"Created {ZIP_PATH} ({ZIP_PATH.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
