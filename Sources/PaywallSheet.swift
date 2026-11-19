import SwiftUI

struct PaywallSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlanID: String = SharedConstants.lifetimeProductID

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if appState.newcomerOfferRemainingSeconds > 0 {
                        let mins = appState.newcomerOfferRemainingSeconds / 60
                        let secs = appState.newcomerOfferRemainingSeconds % 60
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text(
                                appState.lang == .zh
                                    ? String(format: "首日新客清净特惠 · 剩余 %02d:%02d", mins, secs)
                                    : String(format: "Newcomer Launch Offer · %02d:%02d left", mins, secs)
                            )
                            .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.14), in: Capsule())
                    }

                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 46))
                            .foregroundStyle(Color(red: 0.06, green: 0.68, blue: 0.48))

                        Text(appState.lang == .zh ? "升级净盾 Pro · 还手机一生清净" : "CleanShield Pro · Total Peace of Mind")
                            .font(.title3.weight(.heavy))
                            .multilineTextAlignment(.center)

                        if let reason = appState.paywallTriggerReason {
                            Text(reason)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color(red: 0.06, green: 0.65, blue: 0.46))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(red: 0.06, green: 0.68, blue: 0.48).opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    VStack(alignment: .leading, spacing: 11) {
                        benefitRow(
                            icon: "gyroscope",
                            zh: "全量解锁 30 大国民 App 防摇一摇与深藏追踪关停图谱",
                            en: "All 30+ App Anti-Shake & Hidden Ad Opt-Out Guides"
                        )
                        benefitRow(
                            icon: "bell.badge.fill",
                            zh: "个性化广告 180 天到期自动提醒（防悄悄复位）",
                            en: "180-Day Expiration Alerts (Stop Silent Ad Resets)"
                        )
                        benefitRow(
                            icon: "safari.fill",
                            zh: "Safari 防恶意强跳 App 浮层 + 自定义拉黑域名与白名单",
                            en: "Safari Anti-Jump Rules + Custom Block & Safe Domains"
                        )
                        benefitRow(
                            icon: "square.grid.2x2.fill",
                            zh: "全部 12 项桌面一步直达小组件（扫码/乘车码/无痕搜）",
                            en: "All 12 Clean Home Screen Direct-Launch Widget Slots"
                        )
                        benefitRow(
                            icon: "lock.iphone",
                            zh: "100% 纯离线零服务器上传，不读网页密码，一次买断包更新",
                            en: "100% On-Device Offline · Zero Data Collection"
                        )
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))

                    VStack(spacing: 10) {
                        planOptionCard(
                            id: SharedConstants.lifetimeProductID,
                            badge: appState.lang == .zh ? "🔥 90% 用户首选 · 一杯奶茶钱永久买断" : "🔥 BEST VALUE · ONE-TIME LIFETIME",
                            title: appState.lang == .zh ? "永久买断版（无自动续费）" : "Lifetime Unlock (Pay Once)",
                            subtitle: appState.lang == .zh ? "原价 ¥68 · 一次付清永久包后续新机型与规则更新" : "Pay once, own forever including all future rule updates",
                            price: storeManager.displayPrice(for: SharedConstants.lifetimeProductID, lang: appState.lang)
                        )

                        planOptionCard(
                            id: SharedConstants.yearlyProductID,
                            badge: nil,
                            title: appState.lang == .zh ? "年度省心订阅" : "Annual Plan",
                            subtitle: appState.lang == .zh ? "折合每月仅 ¥1 · 自动续期可随时在设置取消" : "Auto-renews yearly · Cancel anytime in Settings",
                            price: storeManager.displayPrice(for: SharedConstants.yearlyProductID, lang: appState.lang) + (appState.lang == .zh ? "/年" : "/yr")
                        )

                        planOptionCard(
                            id: SharedConstants.monthlyProductID,
                            badge: nil,
                            title: appState.lang == .zh ? "月度灵活体验" : "Monthly Plan",
                            subtitle: appState.lang == .zh ? "轻巧救急 · 自动续期可随时取消" : "Auto-renews monthly · Cancel anytime",
                            price: storeManager.displayPrice(for: SharedConstants.monthlyProductID, lang: appState.lang) + (appState.lang == .zh ? "/月" : "/mo")
                        )
                    }

                    if let msg = storeManager.statusMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task {
                            let ok = await storeManager.purchase(selectedPlanID, lang: appState.lang)
                            if ok { dismiss() }
                        }
                    } label: {
                        HStack {
                            if storeManager.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(
                                    selectedPlanID == SharedConstants.lifetimeProductID
                                        ? (appState.lang == .zh ? "立即永久解锁净盾 Pro" : "Unlock Lifetime Pro Now")
                                        : (appState.lang == .zh ? "立即订阅解锁 Pro" : "Continue with Selected Plan")
                                )
                                .font(.headline.weight(.bold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.05, green: 0.68, blue: 0.48), Color(red: 0.06, green: 0.52, blue: 0.62)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                    }
                    .disabled(storeManager.isLoading)

                    // Non-hostile exit (prevents 1-star reviews per commercial-playbook)
                    Button {
                        dismiss()
                    } label: {
                        Text(appState.lang == .zh ? "暂不升级，继续免费使用基础拦截与核心体检 →" : "Not now, keep using Free Core Blocker & Audit →")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    // Guideline 3.1.2 Mandatory Footer Links
                    VStack(spacing: 6) {
                        HStack(spacing: 16) {
                            Button(appState.lang == .zh ? "恢复购买" : "Restore Purchases") {
                                Task { await storeManager.restorePurchases(lang: appState.lang) }
                            }
                            Link(appState.lang == .zh ? "隐私政策" : "Privacy Policy", destination: SharedConstants.privacyURL)
                            Link(appState.lang == .zh ? "使用条款 (EULA)" : "Terms of Use (EULA)", destination: SharedConstants.termsURL)
                        }
                        .font(.caption.weight(.semibold))

                        Text(
                            appState.lang == .zh
                                ? "月卡与年卡为自动续期订阅，确认购买后将向 Apple ID 账户扣款；如需取消请在当前计费周期结束至少 24 小时前前往系统「设置 → Apple 账户 → 订阅」关闭。永久买断版为一次性非消耗型内购，永不续费。"
                                : "Monthly & Annual plans auto-renew unless cancelled at least 24 hours before the end of the current period in Account Settings. Lifetime Unlock is a one-time non-consumable purchase."
                        )
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    }
                    .padding(.top, 4)
                }
                .padding(18)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func benefitRow(icon: String, zh: String, en: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color(red: 0.06, green: 0.65, blue: 0.46))
                .frame(width: 24)
            Text(appState.lang == .zh ? zh : en)
                .font(.footnote.weight(.medium))
        }
    }

    private func planOptionCard(id: String, badge: String?, title: String, subtitle: String, price: String) -> some View {
        let selected = (selectedPlanID == id)
        return Button {
            selectedPlanID = id
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.06, green: 0.65, blue: 0.46), in: Capsule())
                }
                HStack {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selected ? Color(red: 0.06, green: 0.65, blue: 0.46) : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(price)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(selected ? Color(red: 0.06, green: 0.65, blue: 0.46) : .primary)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? Color(red: 0.06, green: 0.65, blue: 0.46) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SettingsProView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var storeManager: StoreManager

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if storeManager.isProUnlocked {
                        HStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.title2)
                                .foregroundStyle(.yellow)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(appState.lang == .zh ? "净盾 Pro 已永久激活" : "CleanShield Pro Active")
                                    .font(.headline)
                                Text(appState.lang == .zh ? "感谢支持独立开发！您已享有全部离线清净特权。" : "All 30+ guides, custom rules & widgets unlocked.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button {
                            appState.presentPaywall(reason: nil)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "crown.fill")
                                    .font(.title2)
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(appState.lang == .zh ? "升级净盾 Pro（一杯奶茶钱永久买断）" : "Upgrade to CleanShield Pro")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(appState.lang == .zh ? "解锁全部 30 项关广告图谱 · 防强跳规则 · 桌面组件" : "Unlock all 30+ guides, anti-jump rules & 8 widget slots")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Button(appState.lang == .zh ? "恢复历史购买" : "Restore Purchases") {
                        Task { await storeManager.restorePurchases(lang: appState.lang) }
                    }
                }

                Section(header: Text(appState.lang == .zh ? "跨品牌家人共享工具" : "Family & Cross-Device Guide")) {
                    Link(destination: SharedConstants.supportURL) {
                        Label(
                            appState.lang == .zh ? "打开 6 大手机品牌（含小米/华为/OV）关广告寻路网页" : "6-Brand Phone Ad Opt-Out Web Guide",
                            systemImage: "iphone.gen3"
                        )
                    }
                }

                Section(header: Text(appState.lang == .zh ? "零隐私承诺与法律条款" : "Zero-Data Promise & Legal")) {
                    HStack {
                        Label(appState.lang == .zh ? "隐私架构" : "Architecture", systemImage: "checkmark.seal.fill")
                        Spacer()
                        Text(appState.lang == .zh ? "100% 本地离线 · 零服务器" : "100% On-Device Offline")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Link(destination: SharedConstants.privacyURL) {
                        Label(appState.lang == .zh ? "隐私政策 (Privacy Policy)" : "Privacy Policy", systemImage: "hand.raised.fill")
                    }
                    Link(destination: SharedConstants.termsURL) {
                        Label(appState.lang == .zh ? "使用条款 (Terms of Use / EULA)" : "Terms of Use (EULA)", systemImage: "doc.text.fill")
                    }
                }
            }
            .navigationTitle(appState.lang == .zh ? "净盾 Pro 与关于" : "Pro & Settings")
        }
    }
}
