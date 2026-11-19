import Foundation

public enum AppLang: String, CaseIterable, Codable, Sendable {
    case zh = "zh"
    case en = "en"

    public static var current: AppLang {
        if let saved = UserDefaults(suiteName: SharedConstants.appGroupID)?.string(forKey: "app_lang"),
           let lang = AppLang(rawValue: saved) {
            return lang
        }
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "zh"
        return preferred.hasPrefix("zh") ? .zh : .en
    }
}

public enum SharedConstants {
    public static let appGroupID = "group.com.yanghe.cleanshield"
    public static let appBundleID = "com.yanghe.cleanshield"
    public static let blockerBundleID = "com.yanghe.cleanshield.blocker"
    public static let widgetBundleID = "com.yanghe.cleanshield.widgets"

    public static let compiledRulesFilename = "compiledBlockerList.json"
    public static let shieldConfigKey = "clean_shield_config_v1"
    public static let completedAuditIDsKey = "completed_audit_ids_v1"
    public static let reminderDatesKey = "audit_reminder_dates_v1"
    public static let pinnedShortcutsKey = "pinned_shortcuts_v1"
    public static let isProUnlockedKey = "is_pro_unlocked_v1"
    public static let firstLaunchTimestampKey = "first_launch_ts_v1"
    public static let didPromptReviewKey = "did_prompt_review_v1"

    public static let privacyURL = URL(string: "https://a3152557994-ship-it.github.io/clean-shield/privacy.html")!
    public static let termsURL = URL(string: "https://a3152557994-ship-it.github.io/clean-shield/terms.html")!
    public static let supportURL = URL(string: "https://a3152557994-ship-it.github.io/clean-shield/")!

    public static let monthlyProductID = "com.yanghe.cleanshield.monthly"
    public static let yearlyProductID = "com.yanghe.cleanshield.yearly"
    public static let lifetimeProductID = "com.yanghe.cleanshield.lifetime"
}

public struct ShieldBlockerConfig: Codable, Equatable, Sendable {
    public var blockWebAds: Bool
    public var blockTrackers: Bool
    public var enableIronWhitelist: Bool
    public var blockJumpBannersPro: Bool
    public var customBlockedDomains: [String]
    public var customWhitelistDomains: [String]

    public init(
        blockWebAds: Bool = true,
        blockTrackers: Bool = true,
        enableIronWhitelist: Bool = true,
        blockJumpBannersPro: Bool = false,
        customBlockedDomains: [String] = [],
        customWhitelistDomains: [String] = []
    ) {
        self.blockWebAds = blockWebAds
        self.blockTrackers = blockTrackers
        self.enableIronWhitelist = enableIronWhitelist
        self.blockJumpBannersPro = blockJumpBannersPro
        self.customBlockedDomains = customBlockedDomains
        self.customWhitelistDomains = customWhitelistDomains
    }
}

public struct QuickLaunchItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let titleZh: String
    public let titleEn: String
    public let subtitleZh: String
    public let subtitleEn: String
    public let symbolName: String
    public let urlScheme: String
    public let isFreeTier: Bool

    public init(
        id: String,
        titleZh: String,
        titleEn: String,
        subtitleZh: String,
        subtitleEn: String,
        symbolName: String,
        urlScheme: String,
        isFreeTier: Bool
    ) {
        self.id = id
        self.titleZh = titleZh
        self.titleEn = titleEn
        self.subtitleZh = subtitleZh
        self.subtitleEn = subtitleEn
        self.symbolName = symbolName
        self.urlScheme = urlScheme
        self.isFreeTier = isFreeTier
    }

    public func title(_ lang: AppLang) -> String {
        lang == .zh ? titleZh : titleEn
    }

    public func subtitle(_ lang: AppLang) -> String {
        lang == .zh ? subtitleZh : subtitleEn
    }
}

public enum QuickLaunchCatalog {
    public static let presets: [QuickLaunchItem] = [
        QuickLaunchItem(
            id: "wx_scan",
            titleZh: "直接扫一扫",
            titleEn: "Quick QR Scan",
            subtitleZh: "一步呼出扫码相机",
            subtitleEn: "Open scanner directly",
            symbolName: "qrcode.viewfinder",
            urlScheme: "weixin://scanqrcode",
            isFreeTier: true
        ),
        QuickLaunchItem(
            id: "ali_scan",
            titleZh: "支付扫一扫",
            titleEn: "Pay QR Scan",
            subtitleZh: "跳过首页流直达扫码",
            subtitleEn: "Direct payment scan",
            symbolName: "viewfinder.circle.fill",
            urlScheme: "alipayqr://platformapi/startapp?saId=10000007",
            isFreeTier: true
        ),
        QuickLaunchItem(
            id: "ali_paycode",
            titleZh: "极速付款码",
            titleEn: "Pay Barcode",
            subtitleZh: "结账秒开不等待",
            subtitleEn: "Instant checkout code",
            symbolName: "barcode.viewfinder",
            urlScheme: "alipayqr://platformapi/startapp?saId=20000056",
            isFreeTier: true
        ),
        QuickLaunchItem(
            id: "sys_settings",
            titleZh: "系统隐私页",
            titleEn: "Privacy Settings",
            subtitleZh: "直达本机权限管理",
            subtitleEn: "Jump to app permissions",
            symbolName: "hand.raised.shield.fill",
            urlScheme: "cleanshield://open-settings",
            isFreeTier: true
        ),
        QuickLaunchItem(
            id: "ali_transit",
            titleZh: "地铁乘车码",
            titleEn: "Transit Pass",
            subtitleZh: "过闸机一步亮码",
            subtitleEn: "Direct transit QR pass",
            symbolName: "tram.fill",
            urlScheme: "alipayqr://platformapi/startapp?saId=200011235",
            isFreeTier: false
        ),
        QuickLaunchItem(
            id: "clean_search",
            titleZh: "纯净搜资料",
            titleEn: "Clean Web Search",
            subtitleZh: "Safari 无追踪搜索",
            subtitleEn: "Tracker-free web search",
            symbolName: "safari.fill",
            urlScheme: "https://duckduckgo.com/",
            isFreeTier: false
        ),
        QuickLaunchItem(
            id: "map_nav",
            titleZh: "零打扰导航",
            titleEn: "Direct Map Nav",
            subtitleZh: "直达路线规划页",
            subtitleEn: "Jump to route planner",
            symbolName: "location.north.line.fill",
            urlScheme: "iosamap://path",
            isFreeTier: false
        ),
        QuickLaunchItem(
            id: "bili_search",
            titleZh: "直达搜视频",
            titleEn: "Direct Video Search",
            subtitleZh: "跳过首页推荐瀑布流",
            subtitleEn: "Skip home feed distraction",
            symbolName: "play.rectangle.fill",
            urlScheme: "bilibili://search",
            isFreeTier: false
        ),
        QuickLaunchItem(
            id: "xhs_search",
            titleZh: "直达查攻略",
            titleEn: "Direct Guide Search",
            subtitleZh: "不刷信息流直奔搜索框",
            subtitleEn: "Open search bar directly",
            symbolName: "magnifyingglass.circle.fill",
            urlScheme: "xhsdiscover://search/result",
            isFreeTier: false
        ),
        QuickLaunchItem(
            id: "zhihu_search",
            titleZh: "直达查问答",
            titleEn: "Direct Q&A Search",
            subtitleZh: "绕开首页推广流",
            subtitleEn: "Direct knowledge search",
            symbolName: "text.magnifyingglass",
            urlScheme: "zhihu://search",
            isFreeTier: false
        ),
        QuickLaunchItem(
            id: "photo_scrub",
            titleZh: "抹照片定位",
            titleEn: "Scrub Photo GPS",
            subtitleZh: "发原图前清掉经纬度",
            subtitleEn: "Strip EXIF/GPS before sharing",
            symbolName: "photo.badge.checkmark.fill",
            urlScheme: "cleanshield://tab/tools",
            isFreeTier: false
        ),
        QuickLaunchItem(
            id: "audit_check",
            titleZh: "隐私复检台",
            titleEn: "Privacy Audit",
            subtitleZh: "检查半年自动复活开关",
            subtitleEn: "Check 180-day reset switches",
            symbolName: "checkmark.shield.fill",
            urlScheme: "cleanshield://tab/audit",
            isFreeTier: false
        )
    ]
}
