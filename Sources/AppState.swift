import Foundation
import SafariServices
import StoreKit
import UIKit
import UserNotifications
import WidgetKit

@MainActor
public final class AppState: ObservableObject {
    @Published public var lang: AppLang {
        didSet {
            defaults.set(lang.rawValue, forKey: "app_lang")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    @Published public var selectedTab: Int = 0
    @Published public var completedAuditIDs: Set<String> = []
    @Published public var reminderDates: [String: Date] = [:]
    @Published public var blockerConfig: ShieldBlockerConfig = ShieldBlockerConfig()
    @Published public var safariExtensionEnabled: Bool = false
    @Published public var pinnedShortcutIDs: [String] = ["wx_scan", "ali_scan", "ali_paycode", "sys_settings"]
    @Published public var showPaywall: Bool = false
    @Published public var paywallTriggerReason: String?
    @Published public var toastMessage: String?

    private let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) ?? .standard

    public init() {
        self.lang = AppLang.current

        if defaults.double(forKey: SharedConstants.firstLaunchTimestampKey) == 0 {
            defaults.set(Date().timeIntervalSince1970, forKey: SharedConstants.firstLaunchTimestampKey)
        }

        if let savedAudit = defaults.stringArray(forKey: SharedConstants.completedAuditIDsKey) {
            self.completedAuditIDs = Set(savedAudit)
        }
        if let rawReminders = defaults.dictionary(forKey: SharedConstants.reminderDatesKey) as? [String: Double] {
            self.reminderDates = rawReminders.mapValues { Date(timeIntervalSince1970: $0) }
        }
        if let data = defaults.data(forKey: SharedConstants.shieldConfigKey),
           let cfg = try? JSONDecoder().decode(ShieldBlockerConfig.self, from: data) {
            self.blockerConfig = cfg
        }
        if let savedPins = defaults.stringArray(forKey: SharedConstants.pinnedShortcutsKey), !savedPins.isEmpty {
            self.pinnedShortcutIDs = savedPins
        } else {
            defaults.set(self.pinnedShortcutIDs, forKey: SharedConstants.pinnedShortcutsKey)
        }

        syncRulesAndReloadBlocker(isPro: defaults.bool(forKey: SharedConstants.isProUnlockedKey))
        refreshSafariExtensionState()
    }

    public var hygieneScore: Int {
        AuditCatalog.calculateScore(completedIDs: completedAuditIDs)
    }

    public var uncheckedCount: Int {
        max(0, AuditCatalog.items.count - completedAuditIDs.count)
    }

    public var newcomerOfferRemainingSeconds: Int {
        let first = defaults.double(forKey: SharedConstants.firstLaunchTimestampKey)
        guard first > 0 else { return 900 }
        let elapsed = Int(Date().timeIntervalSince1970 - first)
        return max(0, 900 - elapsed)
    }

    public func toggleAuditCompleted(_ item: AuditItem, isPro: Bool) {
        if !item.isFreeTier && !isPro {
            presentPaywall(
                reason: lang == .zh
                    ? "已发现剩余 \(AuditCatalog.items.filter { !$0.isFreeTier }.count) 项高频 App 深藏追踪与摇一摇开关"
                    : "Unlock 20+ deep-hidden app ad & sensor guides"
            )
            return
        }

        if completedAuditIDs.contains(item.id) {
            completedAuditIDs.remove(item.id)
        } else {
            completedAuditIDs.insert(item.id)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            maybeRequestAppStoreReview()
        }
        defaults.set(Array(completedAuditIDs), forKey: SharedConstants.completedAuditIDsKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    public func schedule180DayReminder(for item: AuditItem) {
        let days = item.autoResetsDays ?? 180
        let targetDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date().addingTimeInterval(Double(days) * 86400)

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            Task { @MainActor in
                guard let self else { return }
                if granted {
                    let content = UNMutableNotificationContent()
                    content.title = self.lang == .zh ? "🛡️ 净盾提醒：个性化广告开关已满 \(days) 天" : "🛡️ CleanShield: \(days)-Day Privacy Switch Expired"
                    content.body = self.lang == .zh
                        ? "「\(item.titleZh)」的关闭有效期已满，点击打开净盾 30 秒重新关停，防止精准广告复活。"
                        : "Your opt-out for '\(item.titleEn)' has reset. Tap to re-disable in 30 seconds."
                    content.sound = .default

                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(days) * 86400, repeats: false)
                    let req = UNNotificationRequest(identifier: "cleanshield.reset.\(item.id)", content: content, trigger: trigger)
                    try? await UNUserNotificationCenter.current().add(req)

                    self.reminderDates[item.id] = targetDate
                    let raw = self.reminderDates.mapValues { $0.timeIntervalSince1970 }
                    self.defaults.set(raw, forKey: SharedConstants.reminderDatesKey)
                    WidgetCenter.shared.reloadAllTimelines()
                    self.showToast(self.lang == .zh ? "🔔 已设好 \(days) 天到期自动提醒！" : "🔔 \(days)-day expiration reminder set!")
                } else {
                    self.showToast(self.lang == .zh ? "请先在系统设置中允许通知权限" : "Please enable Notifications in Settings first")
                }
            }
        }
    }

    public func updateBlockerConfig(_ mutate: (inout ShieldBlockerConfig) -> Void, isPro: Bool) {
        mutate(&blockerConfig)
        if let data = try? JSONEncoder().encode(blockerConfig) {
            defaults.set(data, forKey: SharedConstants.shieldConfigKey)
        }
        syncRulesAndReloadBlocker(isPro: isPro)
    }

    public func syncRulesAndReloadBlocker(isPro: Bool) {
        _ = try? BlockerRuleCompiler.writeToSharedContainer(config: blockerConfig, isPro: isPro)
        SFContentBlockerManager.reloadContentBlocker(withIdentifier: SharedConstants.blockerBundleID) { [weak self] _ in
            Task { @MainActor in
                self?.refreshSafariExtensionState()
            }
        }
    }

    public func refreshSafariExtensionState() {
        SFContentBlockerManager.getStateOfContentBlocker(withIdentifier: SharedConstants.blockerBundleID) { [weak self] state, _ in
            Task { @MainActor in
                self?.safariExtensionEnabled = (state?.isEnabled == true)
            }
        }
    }

    public func togglePinnedShortcut(_ item: QuickLaunchItem, isPro: Bool) {
        if !item.isFreeTier && !isPro {
            presentPaywall(
                reason: lang == .zh
                    ? "解锁全部 12 项免打扰直达入口与桌面小组件自由编排"
                    : "Unlock all 12 clean direct-launch shortcuts & widget slots"
            )
            return
        }
        if let idx = pinnedShortcutIDs.firstIndex(of: item.id) {
            pinnedShortcutIDs.remove(at: idx)
        } else {
            let maxCount = isPro ? 8 : 4
            if pinnedShortcutIDs.count >= maxCount {
                if !isPro {
                    presentPaywall(
                        reason: lang == .zh
                            ? "免费版支持固定 4 个桌面直达入口，升级 Pro 可扩展至 8 个"
                            : "Free tier supports 4 widget slots. Upgrade to Pro for 8 slots."
                    )
                    return
                } else {
                    pinnedShortcutIDs.removeFirst()
                }
            }
            pinnedShortcutIDs.append(item.id)
        }
        defaults.set(pinnedShortcutIDs, forKey: SharedConstants.pinnedShortcutsKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    public func handleDeepLink(_ url: URL) {
        guard url.scheme == "cleanshield" else { return }
        if url.host == "open-settings" {
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
            return
        }
        if url.host == "tab" {
            let path = url.path.replacingOccurrences(of: "/", with: "")
            switch path {
            case "audit": selectedTab = 0
            case "safari": selectedTab = 1
            case "tools": selectedTab = 2
            case "pro": selectedTab = 3
            default: break
            }
        }
    }

    public func presentPaywall(reason: String?) {
        paywallTriggerReason = reason
        showPaywall = true
    }

    public func showToast(_ text: String) {
        toastMessage = text
        Task {
            try? await Task.sleep(nanoseconds: 2_300_000_000)
            if self.toastMessage == text {
                self.toastMessage = nil
            }
        }
    }

    public func maybeRequestAppStoreReview() {
        guard !defaults.bool(forKey: SharedConstants.didPromptReviewKey),
              completedAuditIDs.count >= 3 else {
            return
        }
        defaults.set(true, forKey: SharedConstants.didPromptReviewKey)
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {
            AppStore.requestReview(in: scene)
        }
    }
}
