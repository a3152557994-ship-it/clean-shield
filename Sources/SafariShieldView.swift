import SwiftUI
import UIKit

struct SafariShieldView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var storeManager: StoreManager

    @State private var newBlockDomain: String = ""
    @State private var newWhiteDomain: String = ""
    @State private var showWhitelistSheet: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusBannerCard
                    zeroPasswordAssuranceCard
                    ruleSwitchesCard
                    customDomainCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(appState.lang == .zh ? "Safari 零权限净盾" : "Safari Web Shield")
            .sheet(isPresented: $showWhitelistSheet) {
                whitelistInspectorSheet
            }
        }
    }

    private var statusBannerCard: some View {
        let active = appState.safariExtensionEnabled
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: active ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(active ? Color(red: 0.25, green: 0.95, blue: 0.68) : Color.yellow)

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        active
                            ? (appState.lang == .zh ? "Safari 净盾扩展已激活守护" : "Safari Content Blocker Active")
                            : (appState.lang == .zh ? "最后一步：在设置中开启净盾开关" : "1 Step Left: Enable in Safari Settings")
                    )
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                    Text(
                        active
                            ? (appState.lang == .zh ? "网页牛皮癣横幅、恶意追踪器已从源头静默拦截" : "Web banners, popups & 3rd-party trackers blocked natively")
                            : (appState.lang == .zh ? "【设置】→【App】→【Safari 浏览器】→【扩展】→ 打开「净盾」" : "Settings → Apps → Safari → Extensions → Turn ON CleanShield")
                    )
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label(
                        appState.lang == .zh ? "前往系统设置开启" : "Open Settings",
                        systemImage: "gearshape.fill"
                    )
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 0.05, green: 0.22, blue: 0.17))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.32, green: 0.95, blue: 0.72), in: Capsule())
                }

                Button {
                    appState.syncRulesAndReloadBlocker(isPro: storeManager.isProUnlocked)
                    appState.showToast(appState.lang == .zh ? "✓ 过滤规则已同步刷新" : "✓ Filter rules refreshed")
                } label: {
                    Label(
                        appState.lang == .zh ? "刷新规则库" : "Reload Rules",
                        systemImage: "arrow.clockwise"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.16), in: Capsule())
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: active
                    ? [Color(red: 0.05, green: 0.28, blue: 0.22), Color(red: 0.06, green: 0.18, blue: 0.25)]
                    : [Color(red: 0.24, green: 0.18, blue: 0.08), Color(red: 0.14, green: 0.14, blue: 0.20)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private var zeroPasswordAssuranceCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "key.slash.fill")
                .font(.title3)
                .foregroundStyle(Color(red: 0.06, green: 0.65, blue: 0.46))
                .frame(width: 34, height: 34)
                .background(Color(red: 0.06, green: 0.65, blue: 0.46).opacity(0.14), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(appState.lang == .zh ? "零密码读取权限 · 绝不弹窗吓人" : "Zero Webpage Read Permission · Total Privacy")
                    .font(.subheadline.weight(.bold))
                Text(
                    appState.lang == .zh
                        ? "普通脚本插件会向系统索要「读取网页密码与银行卡信息」高危权限；净盾采用苹果原生静态过滤引擎，连我们自己也无法看到你浏览了任何网页。"
                        : "Unlike script extensions that trigger scary 'Can read passwords & credit cards' warnings, CleanShield uses Apple's native declarative Content Blocker—blind to your browsing history."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var ruleSwitchesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(appState.lang == .zh ? "核心拦截与防误杀引擎" : "Core Filter Packs")
                .font(.headline)

            Toggle(isOn: Binding(
                get: { appState.blockerConfig.blockWebAds },
                set: { val in
                    appState.updateBlockerConfig({ $0.blockWebAds = val }, isPro: storeManager.isProUnlocked)
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.lang == .zh ? "拦截网页牛皮癣横幅与弹窗广告" : "Block Web Banners & Popups")
                        .font(.subheadline.weight(.semibold))
                    Text(appState.lang == .zh ? "免费开放 · 清理小说站/资讯页悬浮牛皮癣" : "Free · Strips floating banners & ad networks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Toggle(isOn: Binding(
                get: { appState.blockerConfig.blockTrackers },
                set: { val in
                    appState.updateBlockerConfig({ $0.blockTrackers = val }, isPro: storeManager.isProUnlocked)
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.lang == .zh ? "阻断第三方跨站隐私画像追踪器" : "Block 3rd-Party Analytics & Spy Pixels")
                        .font(.subheadline.weight(.semibold))
                    Text(appState.lang == .zh ? "免费开放 · 阻止广告联盟采集浏览指纹" : "Free · Stops cross-site behavioral fingerprinting")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Toggle(isOn: Binding(
                get: { appState.blockerConfig.enableIronWhitelist },
                set: { val in
                    appState.updateBlockerConfig({ $0.enableIronWhitelist = val }, isPro: storeManager.isProUnlocked)
                }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(appState.lang == .zh ? "民生地图/银行/运营商零误杀铁白名单" : "Maps, Banking & Carrier Safe Whitelist")
                            .font(.subheadline.weight(.semibold))
                        Button {
                            showWhitelistSheet = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.caption)
                        }
                    }
                    Text(appState.lang == .zh ? "出厂锁死高德/百度地图、四大行、10086、微信支付永不断流" : "Protects Maps, Banks, Carriers & Apple services from false blocks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Toggle(isOn: Binding(
                get: { storeManager.isProUnlocked && appState.blockerConfig.blockJumpBannersPro },
                set: { val in
                    if !storeManager.isProUnlocked {
                        appState.presentPaywall(
                            reason: appState.lang == .zh
                                ? "解锁 Safari 防恶意强跳 App 横幅与净阅遮罩清理"
                                : "Unlock Anti-App-Jump Banner & Clean Reader Rules"
                        )
                    } else {
                        appState.updateBlockerConfig({ $0.blockJumpBannersPro = val }, isPro: true)
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(appState.lang == .zh ? "隐藏「强制打开 App 看全文」诱导浮层" : "Hide 'Open in App' Sticky Prompts")
                            .font(.subheadline.weight(.semibold))
                        Text("PRO")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                    }
                    Text(appState.lang == .zh ? "压制底部悬浮唤醒条与诱导下载遮罩" : "Suppresses annoying sticky app-install callout bars")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var customDomainCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(appState.lang == .zh ? "自定义屏蔽域名与专属白名单" : "Custom Block & Safe Domains")
                    .font(.headline)
                Spacer()
                if !storeManager.isProUnlocked {
                    Text("PRO")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                }
            }

            HStack {
                TextField(appState.lang == .zh ? "输入想屏蔽的广告域名，如 ad.example.com" : "Domain to block (e.g. ads.example.com)", text: $newBlockDomain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.footnote)
                    .textFieldStyle(.roundedBorder)

                Button(appState.lang == .zh ? "拉黑" : "Block") {
                    guard storeManager.isProUnlocked else {
                        appState.presentPaywall(reason: appState.lang == .zh ? "解锁自定义域名拉黑与个人白名单管理" : "Unlock custom domain blocking & whitelisting")
                        return
                    }
                    if let dom = BlockerRuleCompiler.sanitizeDomain(newBlockDomain) {
                        appState.updateBlockerConfig({ cfg in
                            if !cfg.customBlockedDomains.contains(dom) {
                                cfg.customBlockedDomains.append(dom)
                            }
                        }, isPro: true)
                        newBlockDomain = ""
                        appState.showToast(appState.lang == .zh ? "已加入屏蔽：\(dom)" : "Blocked \(dom)")
                    } else {
                        appState.showToast(appState.lang == .zh ? "请输入有效域名" : "Enter a valid domain")
                    }
                }
                .font(.caption.weight(.bold))
                .buttonStyle(.borderedProminent)
            }

            if !appState.blockerConfig.customBlockedDomains.isEmpty {
                FlowTagsView(items: appState.blockerConfig.customBlockedDomains, tint: .red) { dom in
                    appState.updateBlockerConfig({ $0.customBlockedDomains.removeAll { $0 == dom } }, isPro: storeManager.isProUnlocked)
                }
            }

            HStack {
                TextField(appState.lang == .zh ? "输入永不拦截的信任域名" : "Domain to trust (whitelist)", text: $newWhiteDomain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.footnote)
                    .textFieldStyle(.roundedBorder)

                Button(appState.lang == .zh ? "放行" : "Trust") {
                    guard storeManager.isProUnlocked else {
                        appState.presentPaywall(reason: appState.lang == .zh ? "解锁自定义信任白名单域名" : "Unlock custom whitelist domains")
                        return
                    }
                    if let dom = BlockerRuleCompiler.sanitizeDomain(newWhiteDomain) {
                        appState.updateBlockerConfig({ cfg in
                            if !cfg.customWhitelistDomains.contains(dom) {
                                cfg.customWhitelistDomains.append(dom)
                            }
                        }, isPro: true)
                        newWhiteDomain = ""
                        appState.showToast(appState.lang == .zh ? "已加入信任白名单：\(dom)" : "Trusted \(dom)")
                    }
                }
                .font(.caption.weight(.bold))
                .buttonStyle(.bordered)
            }

            if !appState.blockerConfig.customWhitelistDomains.isEmpty {
                FlowTagsView(items: appState.blockerConfig.customWhitelistDomains, tint: .green) { dom in
                    appState.updateBlockerConfig({ $0.customWhitelistDomains.removeAll { $0 == dom } }, isPro: storeManager.isProUnlocked)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var whitelistInspectorSheet: some View {
        NavigationStack {
            List {
                Section(
                    header: Text(appState.lang == .zh ? "为什么内置铁白名单？" : "Why Built-in Safe Whitelist?"),
                    footer: Text(appState.lang == .zh ? "以上民生域名均位于规则最底层优先级（ignore-previous-rules），确保导航、扫码付款、网银与运营商服务 100% 流畅可用。" : "Evaluated last using WebKit ignore-previous-rules so maps, banking, and payments never break.")
                ) {
                    ForEach(BlockerRuleCompiler.ironWhitelistDomains, id: \.self) { dom in
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text(dom)
                                .font(.subheadline.monospaced())
                        }
                    }
                }
            }
            .navigationTitle(appState.lang == .zh ? "26 项民生免误杀白名单" : "Protected Safe Domains")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.lang == .zh ? "完成" : "Done") {
                        showWhitelistSheet = false
                    }
                }
            }
        }
    }
}

private struct FlowTagsView: View {
    let items: [String]
    let tint: Color
    let onRemove: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: 4) {
                        Text(item)
                            .font(.caption.monospaced())
                        Button {
                            onRemove(item)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(tint.opacity(0.12), in: Capsule())
                }
            }
        }
    }
}
