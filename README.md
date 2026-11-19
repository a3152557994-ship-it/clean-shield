# 🛡️ 净盾 CleanShield (`clean-shield`)

**iOS 原生防摇一摇与隐私关停体检 App + 零密码权限 Safari 网页净盾 + 6 大手机品牌隐藏广告开关寻路台**

- 🌐 **跨品牌在线关广告与防偷听工作台**：[https://a3152557994-ship-it.github.io/clean-shield/](https://a3152557994-ship-it.github.io/clean-shield/)
- 📦 **安卓免 Root 防摇一摇与零误杀配置包**：[https://a3152557994-ship-it.github.io/clean-shield/downloads/clean-shield-android-kit.zip](https://a3152557994-ship-it.github.io/clean-shield/downloads/clean-shield-android-kit.zip)
- 🔒 **隐私政策 (Privacy Policy)**：[https://a3152557994-ship-it.github.io/clean-shield/privacy.html](https://a3152557994-ship-it.github.io/clean-shield/privacy.html)
- 📄 **使用条款 (Terms of Use / EULA)**：[https://a3152557994-ship-it.github.io/clean-shield/terms.html](https://a3152557994-ship-it.github.io/clean-shield/terms.html)

---

## 核心战略差异化（直击竞品 3 大 1★ 差评软肋）

1. **零密码读取权限恐吓**：采用 Apple 官方原生声明式 `SFContentBlocker`，绝不向用户索要「读取网页密码与信用卡信息」高危权限。
2. **26 项民生免误杀铁白名单**：所有规则末尾强制压入 `ignore-previous-rules` 铁白名单（高德地图、百度地图、四大行、10086/10010/189、微信支付、支付宝、12306），杜绝同类 DNS 拦截工具把正常导航与网银搞断网的顽疾。
3. **专治同域开屏「摇一摇」与「每 180 天自动复活」**：内置 30 项系统及国民 App 深藏的传感器断电与个性化广告关停路线，附带本地通知到期重关提醒、发原图前一键剥离 GPS 经纬度、以及桌面一步直达小组件。

## 工程目录与一键指令

- `Sources/`：iOS 18+ SwiftUI 主应用（中英双语自适应 + StoreKit 2 订阅/永久买断 + 照片 EXIF/GPS 抹除器）。
- `BlockerExtension/`：Safari 声明式内容拦截器扩展 (`com.yanghe.cleanshield.blocker`)。
- `Widgets/`：桌面清净分与一步直达小组件 (`com.yanghe.cleanshield.widgets`)。
- `Tests/`：XCTest 自动化测试套件（校验白名单末位优先级、照片 GPS 剥离与体检计分）。
- `docs/`：6 大手机品牌双语在线寻路台与合规法务页。
- `Scripts/asc_sync.py`：App Store Connect 10 国语言元数据、3 档内购与商店截图一键同步脚本。
