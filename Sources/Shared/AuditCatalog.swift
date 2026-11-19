import Foundation

public enum AuditCategory: String, CaseIterable, Codable, Sendable {
    case all = "all"
    case shakeAd = "shake"
    case listeningAd = "listening"
    case systemTrack = "system"

    public func label(_ lang: AppLang) -> String {
        switch (self, lang) {
        case (.all, .zh): return "全部体检"
        case (.all, .en): return "All Checks"
        case (.shakeAd, .zh): return "防摇一摇乱跳"
        case (.shakeAd, .en): return "Stop Shake-Ads"
        case (.listeningAd, .zh): return "防偷听推广告"
        case (.listeningAd, .en): return "Ad Personalization"
        case (.systemTrack, .zh): return "系统隐私追踪"
        case (.systemTrack, .en): return "System Privacy"
        }
    }
}

public struct AuditItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let category: AuditCategory
    public let symbolName: String
    public let titleZh: String
    public let titleEn: String
    public let painZh: String
    public let painEn: String
    public let stepsZh: [String]
    public let stepsEn: [String]
    public let searchKeywordZh: String
    public let searchKeywordEn: String
    public let isFreeTier: Bool
    public let opensSystemSettings: Bool
    public let autoResetsDays: Int?
    public let weight: Int

    public func title(_ lang: AppLang) -> String { lang == .zh ? titleZh : titleEn }
    public func pain(_ lang: AppLang) -> String { lang == .zh ? painZh : painEn }
    public func steps(_ lang: AppLang) -> [String] { lang == .zh ? stepsZh : stepsEn }
    public func searchKeyword(_ lang: AppLang) -> String { lang == .zh ? searchKeywordZh : searchKeywordEn }
}

public enum AuditCatalog {
    public static func calculateScore(completedIDs: Set<String>) -> Int {
        let totalWeight = items.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return 100 }
        let earned = items.filter { completedIDs.contains($0.id) }.reduce(0) { $0 + $1.weight }
        // Base 15 points + up to 85 points from completing audit switches
        return min(100, 15 + Int(round(Double(earned) / Double(totalWeight) * 85.0)))
    }

    public static let items: [AuditItem] = [
        // ================= 10 FREE CORE ITEMS =================
        AuditItem(
            id: "ios_motion_restrict",
            category: .shakeAd,
            symbolName: "gyroscope",
            titleZh: "iOS 系统级切断「动作数据」防摇一摇",
            titleEn: "iOS Motion Sensor Lock (Anti-Shake Jump)",
            painZh: "走路、坐车轻微晃动手机就触发开屏「摇一摇」强跳购物页",
            painEn: "Slight movement triggers splash-screen gyroscope redirects",
            stepsZh: [
                "打开 iPhone【设置】→【隐私与安全性】",
                "点击【运动与健身】",
                "国行新系统点【限制动作数据】把爱乱跳的 App 加进去；或直接将下方无需计步的购物/资讯 App 权限关掉"
            ],
            stepsEn: [
                "Open iPhone Settings → Privacy & Security",
                "Tap Motion & Fitness",
                "Disable Motion access for shopping/news apps (or add them to Restrict Motion Data)"
            ],
            searchKeywordZh: "运动与健身",
            searchKeywordEn: "Motion & Fitness",
            isFreeTier: true,
            opensSystemSettings: true,
            autoResetsDays: nil,
            weight: 6
        ),
        AuditItem(
            id: "ios_att_tracking",
            category: .systemTrack,
            symbolName: "hand.raised.fill",
            titleZh: "全局禁止「允许 App 请求跟踪」",
            titleEn: "Disable Cross-App Tracking (ATT)",
            painZh: "刚在 A 软件搜完商品，打开 B 软件满屏推同款广告",
            painEn: "Apps share your device ID to follow your searches across apps",
            stepsZh: [
                "打开 iPhone【设置】→【隐私与安全性】",
                "点击顶部【跟踪】",
                "将【允许 App 请求跟踪】总开关彻底关闭（变灰）"
            ],
            stepsEn: [
                "Open Settings → Privacy & Security",
                "Tap Tracking at the top",
                "Turn OFF 'Allow Apps to Request to Track'"
            ],
            searchKeywordZh: "跟踪",
            searchKeywordEn: "Tracking",
            isFreeTier: true,
            opensSystemSettings: true,
            autoResetsDays: nil,
            weight: 5
        ),
        AuditItem(
            id: "ios_apple_ad",
            category: .listeningAd,
            symbolName: "megaphone.fill",
            titleZh: "关闭 Apple 官方「个性化广告」画像",
            titleEn: "Turn Off Apple Personalized Ads",
            painZh: "系统根据下载与账单偏好建立你的商业广告画像",
            painEn: "Stops Apple from profiling your purchases for targeted ads",
            stepsZh: [
                "打开 iPhone【设置】→【隐私与安全性】",
                "拉到最底部点击【Apple 广告】",
                "关闭【个性化广告】开关"
            ],
            stepsEn: [
                "Open Settings → Privacy & Security",
                "Scroll to bottom and tap Apple Advertising",
                "Toggle OFF 'Personalized Ads'"
            ],
            searchKeywordZh: "Apple 广告",
            searchKeywordEn: "Apple Advertising",
            isFreeTier: true,
            opensSystemSettings: true,
            autoResetsDays: nil,
            weight: 4
        ),
        AuditItem(
            id: "ios_pasteboard",
            category: .systemTrack,
            symbolName: "doc.on.clipboard.fill",
            titleZh: "封堵「后台偷读剪贴板」防口令泄露",
            titleEn: "Block Silent Clipboard Snooping",
            painZh: "复制一段聊天文字或地址，打开别的 App 立刻被读取推广告",
            painEn: "Apps silently read copied text, addresses, and links on launch",
            stepsZh: [
                "打开 iPhone【设置】→【App】→ 选择常用购物/资讯软件",
                "点击【从其他 App 粘贴】",
                "改为【拒绝】或【询问】，杜绝后台静默偷读"
            ],
            stepsEn: [
                "Open Settings → Apps → Select target app",
                "Tap 'Paste from Other Apps'",
                "Set to 'Deny' or 'Ask' instead of 'Allow'"
            ],
            searchKeywordZh: "从其他 App 粘贴",
            searchKeywordEn: "Paste from Other Apps",
            isFreeTier: true,
            opensSystemSettings: true,
            autoResetsDays: nil,
            weight: 5
        ),
        AuditItem(
            id: "ios_safari_privacy",
            category: .systemTrack,
            symbolName: "safari.fill",
            titleZh: "开启 Safari「阻止跨网站跟踪 + 隐藏 IP」",
            titleEn: "Safari Cross-Site Tracker & IP Shield",
            painZh: "浏览网页后被广告联盟植入追踪 Cookie 一路尾随",
            painEn: "Web ad networks fingerprint your IP and Safari cookies",
            stepsZh: [
                "打开 iPhone【设置】→【App】→【Safari 浏览器】",
                "下滑找到「隐私与安全性」栏",
                "开启【阻止跨网站跟踪】并将【隐藏 IP 地址】设为「对跟踪器隐藏」"
            ],
            stepsEn: [
                "Open Settings → Apps → Safari",
                "Scroll to Privacy & Security",
                "Enable 'Prevent Cross-Site Tracking' and 'Hide IP Address'"
            ],
            searchKeywordZh: "Safari 浏览器",
            searchKeywordEn: "Safari",
            isFreeTier: true,
            opensSystemSettings: true,
            autoResetsDays: nil,
            weight: 4
        ),
        AuditItem(
            id: "ios_significant_loc",
            category: .systemTrack,
            symbolName: "location.slash.fill",
            titleZh: "关闭系统底层「重要地点」行踪记录",
            titleEn: "Disable Hidden Significant Locations",
            painZh: "手机每天自动记录你去过哪栋楼、住了几晚并用于位置推荐",
            painEn: "Logs every address you visit and how long you stay",
            stepsZh: [
                "打开【设置】→【隐私与安全性】→【定位服务】",
                "拉到底部点【系统服务】",
                "关闭【重要地点】、【位置分享建议】与【iPhone 分析】"
            ],
            stepsEn: [
                "Open Settings → Privacy & Security → Location Services",
                "Scroll down to System Services",
                "Turn OFF 'Significant Locations' & 'iPhone Analytics'"
            ],
            searchKeywordZh: "定位服务",
            searchKeywordEn: "Location Services",
            isFreeTier: true,
            opensSystemSettings: true,
            autoResetsDays: nil,
            weight: 4
        ),
        AuditItem(
            id: "app_chat_ad_6m",
            category: .listeningAd,
            symbolName: "bubble.left.and.bubble.right.fill",
            titleZh: "国民聊天软件：关停朋友圈与订阅号定向广告（每半年自动失效！）",
            titleEn: "Messenger App: Personalized Ad Opt-Out (180-Day Reset!)",
            painZh: "刚在群里聊到装修、旅游或奶粉，朋友圈第 5 条立刻刷出精准广告；且每 6 个月会自动恢复开启！",
            painEn: "Targeted Moments ads reappear every 6 months unless re-disabled",
            stepsZh: [
                "打开聊天软件【我】→【设置】→【个人信息与权限】",
                "点击【个性化广告管理】→ 关闭【个性化广告】",
                "重点补刀：退回【设置】→【关于】→ 底部蓝字《隐私保护指引》→ 点「我们如何使用信息」里的【关于广告】→【管理】登录彻底关满 6 个月（建议开启下方 180 天到期提醒）"
            ],
            stepsEn: [
                "Open Me → Settings → Personal Info & Permissions",
                "Tap Personalized Ads Management → Toggle OFF",
                "Enable the 180-day reminder below so you get alerted when it silently resets"
            ],
            searchKeywordZh: "个性化广告管理",
            searchKeywordEn: "Personalized Ads",
            isFreeTier: true,
            opensSystemSettings: false,
            autoResetsDays: 180,
            weight: 6
        ),
        AuditItem(
            id: "app_shop_tb",
            category: .shakeAd,
            symbolName: "cart.fill",
            titleZh: "主流综合购物软件：双关「传感器摇一摇 + 个性化广告」",
            titleEn: "Top Shopping App: Disable Shake-Jump & Ad Profiling",
            painZh: "后台挂着或切屏时极易被别的软件唤醒跳转，且首页猜你喜欢越刷越精准",
            painEn: "Stops aggressive cross-app wakeups and behavioral ad targeting",
            stepsZh: [
                "打开购物软件【我的】→ 右上角齿轮【设置】→【隐私】",
                "点击【广告管理】关闭【程序化广告展示设置】",
                "返回【隐私】→【系统权限管理】→ 关闭麦克风、位置及通讯录权限"
            ],
            stepsEn: [
                "Open My Account → Settings (Gear) → Privacy",
                "Tap Ad Management → Turn OFF Programmatic Personalized Ads",
                "Revoke Microphone & Contacts in System Permissions"
            ],
            searchKeywordZh: "广告管理",
            searchKeywordEn: "Ad Management",
            isFreeTier: true,
            opensSystemSettings: false,
            autoResetsDays: nil,
            weight: 5
        ),
        AuditItem(
            id: "app_short_video_dy",
            category: .listeningAd,
            symbolName: "play.tv.fill",
            titleZh: "短视频平台：关闭「程序化与个性化广告展示」",
            titleEn: "Short-Video App: Turn Off Targeted Ad Stream",
            painZh: "刷 3 条视频就夹 1 条精准直播带货/游戏推广，越停留推得越狠",
            painEn: "Reduces hyper-targeted ad insertions in your video feed",
            stepsZh: [
                "打开短视频 App【我】→ 右上角三条杠【设置】",
                "下滑进入【个人信息管理】（或【了解与管理广告推送】）",
                "将【程序化广告展示设置】与【个性化广告展示设置】双双关闭"
            ],
            stepsEn: [
                "Open Profile → Menu (≡) → Settings",
                "Tap Personal Information / Manage Ad Push",
                "Turn OFF both Programmatic & Personalized Ad Display"
            ],
            searchKeywordZh: "了解与管理广告推送",
            searchKeywordEn: "Manage Ad Push",
            isFreeTier: true,
            opensSystemSettings: false,
            autoResetsDays: nil,
            weight: 4
        ),
        AuditItem(
            id: "ios_mic_audit",
            category: .listeningAd,
            symbolName: "mic.slash.fill",
            titleZh: "一键清退非语音类 App「麦克风」后台权限",
            titleEn: "Audit & Revoke Unneeded Microphone Access",
            painZh: "购物、外卖、输入法、修图软件索要麦克风权限，带来日常谈话被采集顾虑",
            painEn: "Shopping and utility apps don't need live microphone access",
            stepsZh: [
                "打开 iPhone【设置】→【隐私与安全性】→【麦克风】",
                "除微信/电话/会议/语音备忘录外，把购物、资讯、输入法、浏览器麦克风权限全部关掉"
            ],
            stepsEn: [
                "Open Settings → Privacy & Security → Microphone",
                "Turn OFF microphone access for shopping, news, keyboard, and utility apps"
            ],
            searchKeywordZh: "麦克风",
            searchKeywordEn: "Microphone",
            isFreeTier: true,
            opensSystemSettings: true,
            autoResetsDays: nil,
            weight: 5
        ),

        // ================= 20 PRO DEEP-APP ITEMS =================
        AuditItem(
            id: "pro_alipay_ad",
            category: .listeningAd,
            symbolName: "creditcard.fill",
            titleZh: "国民支付工具：关闭商业推广与首页繁杂卡片",
            titleEn: "Payment Wallet: Disable Commercial Ad Cards",
            painZh: "付完钱弹窗推借贷保险，首页下拉全是无关生活号营销流",
            painEn: "Stops post-payment loan popups and noisy home feed cards",
            stepsZh: [
                "打开【我的】→ 右上角齿轮【设置】→【隐私】→【常用隐私设置】",
                "关闭【个性化推荐】与【向好友公开我的真实姓名】",
                "退回【设置】→【功能管理】→【首页栏目卡片】一键关掉多余推广卡片"
            ],
            stepsEn: [
                "Open Me → Settings → Privacy → Common Privacy Settings",
                "Turn OFF Personalized Recommendations",
                "Go to Settings → Function Management → Home Cards and hide promo modules"
            ],
            searchKeywordZh: "常用隐私设置",
            searchKeywordEn: "Privacy Settings",
            isFreeTier: false,
            opensSystemSettings: false,
            autoResetsDays: nil,
            weight: 3
        ),
        AuditItem(
            id: "pro_jd_shake",
            category: .shakeAd,
            symbolName: "bag.fill",
            titleZh: "自营电商软件：关停开屏敏感跳转与商业广告",
            titleEn: "E-Commerce App: Stop Splash Redirects & Ad Push",
            painZh: "大促期间一打开就全屏动效误触进入会场，消息栏天天弹促销红点",
            painEn: "Prevents accidental promo-hall jumps and marketing badge spam",
            stepsZh: [
                "打开【我的】→ 右上角齿轮【账户设置】→【通用】→【隐私设置】",
                "点击【广告管理】关闭【个性化广告推荐】",
                "在系统【设置 → 隐私 → 运动与健身】确认已禁止其读取陀螺仪"
            ],
            stepsEn: [
                "Open Account Settings → General → Privacy Settings",
                "Tap Ad Management → Turn OFF Personalized Ads",
                "Verify Motion & Fitness access is disabled in iOS Settings"
            ],
            searchKeywordZh: "隐私设置",
            searchKeywordEn: "Privacy Settings",
            isFreeTier: false,
            opensSystemSettings: false,
            autoResetsDays: nil,
            weight: 3
        ),
        AuditItem(
            id: "pro_pdd_clean",
            category: .listeningAd,
            symbolName: "gift.fill",
            titleZh: "拼团购物软件：关停现金转盘弹窗与好友拼单广播",
            titleEn: "Group-Buy App: Silence Spin-Wheel & Friend Broadcasts",
            painZh: "买的私密日用品被自动同步到熟人圈「好友买过」，且营销弹窗不断",
            painEn: "Hides your purchases from contacts and cuts promo popups",
            stepsZh: [
                "打开【个人中心】→【设置】→【拼小圈设置】→ 选择【关闭拼小圈】",
                "返回【设置】→【常见问题/隐私】关闭个性化商品与广告推荐",
                "进入【消息接收设置】关掉优惠活动通知"
            ],
            stepsEn: [
                "Open Profile → Settings → Social Circle → Disable Circle",
                "Disable Personalized Promo & Marketing Push Notifications"
            ],
            searchKeywordZh: "消息接收设置",
            searchKeywordEn: "Notification Settings",
            isFreeTier: false,
            opensSystemSettings: false,
            autoResetsDays: nil,
            weight: 3
        ),
        AuditItem(
            id: "pro_meituan_ad",
            category: .listeningAd,
            symbolName: "fork.knife.circle.fill",
            titleZh: "本地外卖团购：关闭小贷推广与个性化广告",
            titleEn: "Food Delivery App: Stop Loan & Personalized Ads",
            painZh: "点个外卖结账页反复诱导开通月付借钱，首页短视频流耗电烦人",
            painEn: "Removes personalized ad banners and noisy feed push",
            stepsZh: [
                "打开【我的】→ 右上角【设置】→【个人信息与权限】",
                "点击【个性化管理】→ 将【个性化广告】与【个性化内容】全部关闭",
                "在【通知与提醒】里关闭营销活动推送"
            ],
            stepsEn: [
                "Open Me → Settings → Personal Info & Permissions",
                "Tap Personalization → Turn OFF Personalized Ads & Content"
            ],
            searchKeywordZh: "个性化管理",
            searchKeywordEn: "Personalization",
            isFreeTier: false,
            opensSystemSettings: false,
            autoResetsDays: nil,
            weight: 3
        ),
        AuditItem(
            id: "pro_netdisk_shake",
            category: .shakeAd,
            symbolName: "externaldrive.fill.badge.icloud",
            titleZh: "云盘与搜索软件：掐断摇一摇与后台备份推广",
            titleEn: "Cloud Drive & Search: Cut Shake-Ads & Promo Feeds",
            painZh: "只想存个工作文件，开屏一晃就跳走（纯网络拦截根本拦不住同域开屏）",
            painEn: "Same-domain splash ads bypass network blockers; cut sensor access instead",
            stepsZh: [
                "打开云盘【我的】→【设置】→【隐私设置】→【个性化广告管理】关闭开关",
                "返回【设置】→【消息提醒设置】关闭活动推送",
                "关键一步：去 iPhone【设置 → 隐私与安全性 → 运动与健身】关掉它的传感器开关，摇一摇彻底失灵"
            ],
            stepsEn: [
                "Open Me → Settings → Privacy → Turn OFF Personalized Ads",
                "Revoke Motion & Fitness sensor permission in iOS Settings so shake-ads cannot trigger"
            ],
            searchKeywordZh: "个性化广告管理",
            searchKeywordEn: "Personalized Ads",
            isFreeTier: false,
            opensSystemSettings: false,
            autoResetsDays: 180,
            weight: 3
        ),
        AuditItem(
            id: "pro_xhs_privacy",
            category: .listeningAd,
            symbolName: "book.pages.fill",
            titleZh: "种草社区：关闭个性化广告与「可能认识的人」暴露",
            titleEn: "Lifestyle Feed: Stop Ad Profiling & Contact Exposure",
            painZh: "小号动态被推给通讯录同事老板，搜过一次的品类满屏跟投广告笔记",
            painEn: "Prevents contact-based account discovery and ad retargeting",
            stepsZh: [
                "打开【我】→ 左上角三条杠【设置】→【隐私设置】",
                "开启【不把我推荐给可能认识的人】",
                "退回【设置】→【通用设置】→【个性化选项】关闭【个性化广告】"
            ],
            stepsEn: [
                "Open Me → Settings → Privacy → Enable 'Do Not Suggest Me to Contacts'",
                "Go to General Settings → Personalization → Turn OFF Personalized Ads"
            ],
            searchKeywordZh: "个性化选项",
            searchKeywordEn: "Personalization",
            isFreeTier: false,
            opensSystemSettings: false,
            autoResetsDays: nil,
            weight: 3
        ),
        AuditItem(
            id: "pro_weibo_shake",
            category: .shakeAd,
            symbolName: "flame.fill",
            titleZh: "社交热搜客户端：废掉高频开屏倾角跳转与流内广告",
            titleEn: "Microblog App: Disable Tilt-Jump & Feed Ad Tracking",
            painZh: "开屏稍微倾斜 15 度就跳第三方电商，是摇一摇误触最严重的软件之一",
            painEn: "Notorious low-threshold tilt-to-jump splash ads",
            stepsZh: [
                "先在 iPhone【设置 → 隐私与安全性 → 运动与健身】关掉它的权限",
                "打开客户端【我】→ 右上角齿轮【设置】→【隐私设置】",
                "拉到底点击【个人信息与权限】→【个性化广告管理】关闭开关"
            ],
            stepsEn: [
                "Revoke Motion & Fitness permission in iOS Settings first",
                "In app: Me → Settings → Privacy → Personal Info → Turn OFF Personalized Ads"
            ],
            searchKeywordZh: "个性化广告管理",
            searchKeywordEn: "Personalized Ads",
            isFreeTier: false,
            opensSystemSettings: false,
            autoResetsDays: nil,
            weight: 3
        ),
        AuditItem(
            id: "pro_zhihu_shake",
            category: .shakeAd,
            symbolName: "questionmark.bubble.fill",
            titleZh: "问答社区：关闭摇一摇与测评软文定向投喂",
            titleEn: "Q&A Community: Stop Shake-Ads & Targeted Ad Posts",
            painZh: "查个正经问题先被开屏晃跳走，回答中间还穿插高度伪装的广告卡片",
            painEn: "Eliminates motion-triggered redirects and targeted promo cards",
            stepsZh: [
                "打开【我的】→ 右上角齿轮【设置】→【隐私中心】",
                "点击【权限与账号安全】或【广告设置】→ 关闭【程序化广告展示】",
                "在系统隐私里关闭其「运动与健身」与「本地网络」权限"
            ],
            stepsEn: [
                "Open Profile → Settings → Privacy Center → Ad Settings",
                "Turn OFF Programmatic Ads and revoke iOS Motion access"
            ],
            searchKeywordZh: "隐私中心",
            searchKeywordEn: "Privacy Center",
            isFreeTier: false,
            opensSystemSettings: false,
            autoResetsDays: nil,
            weight: 2
        ),
        AuditItem(
            id: "pro_bili_ad",
            category: .listeningAd,
            symbolName: "sparkles.tv.fill",
            titleZh: "弹幕视频社区：关闭定向商业起飞推广与权限",
            titleEn: "Video Community: Disable Targeted Promo Cards",
            painZh: "首页双列流频繁刷出游戏下载与培训课定向卡片",
            painEn: "Cuts targeted game/course ad cards on your home grid",
            stepsZh: [
                "打开【我的】→ 拉到底【设置】→【安全隐私】",
                "点击【隐私权限设置】→ 拉到底关闭【允许个性化广告推荐】"
            ],
            stepsEn: [
                "Open Mine → Settings → Safety & Privacy",
                "Tap Privacy Permissions → Turn OFF Personalized Ad Recommendations"
            ],
            searchKeywordZh: "安全隐私",
            searchKeywordEn: "Safety & Privacy",
            isFreeTier: false,
            opensSystemSettings: false,
            autoResetsDays: nil,
            weight: 2
        ),
        AuditItem(
            id: "pro_amap_clean",
            category: .shakeAd,
            symbolName: "map.fill",
            titleZh: "导航地图：关闭驾车语音播报插播广告与周边推荐",
            titleEn: "Navigation Map: Silence Voice Promo & Feed Ads",
            painZh: "开车看导航时误触跳转极危险，等红灯时弹周边团购推广",
            painEn: "Prevents distracting promo popups while driving",
            stepsZh: [
                "打开地图【我的】→ 右上角齿轮【设置】→【隐私与权限管理】",
                "点击【广告屏蔽管理】（或【个性化推荐设置】）关闭【个性化广告】",
                "进入【导航设置】关闭「场景推荐」与「语音助手闲聊推广」"
            ],
            stepsEn: [
                "Open Mine → Settings → Privacy & Permissions",
                "Turn OFF Personalized Ads and disable Navigation Promo Tips"
            ],
            searchKeywordZh: "隐私与权限管理",
            searchKeywordEn: "Privacy & Permissions",
            isFreeTier: false,
            opensSystemSettings: false,
            autoResetsDays: nil,
            weight: 3
        ),
        AuditItem(
            id: "pro_cainiao_shake",
            category: .shakeAd,
            symbolName: "shippingbox.fill",
            titleZh: "查快递取件软件：根治取件码页摇一摇乱跳",
            titleEn: "Parcel Pickup App: Stop Pickup-Code Shake Jumps",
            painZh: "站在驿站门口后面排着队，刚掏出手机看取件码一晃跳去购物会场，急死人",
            painEn: "Stops shake-redirects right when you're trying to show your pickup code",
            stepsZh: [
                "在 iPhone【设置 → 隐私与安全性 → 运动与健身】关闭取件软件动作权限",
                "打开取件 App【我的】→【设置】→【隐私】→ 关闭【个性化广告管理】"
            ],
            stepsEn: [
                "Disable Motion & Fitness for the parcel app in iOS Settings",
                "In app: Mine → Settings → Privacy → Turn OFF Personalized Ads"
            ],
            searchKeywordZh: "个性化广告",
            searchKeywordEn: "Personalized Ads",
            isFreeTier: false,
            opensSystemSettings: true,
            autoResetsDays: nil,
            weight: 3
        ),
        AuditItem(
            id: "pro_music_wy",
            category: .shakeAd,
            symbolName: "headphones",
            titleZh: "音乐播放器：关停切歌时开屏摇一摇与直播悬浮窗",
            titleEn: "Music Player: Stop Shake-Ads & Live-Stream Floats",
            painZh: "跑步戴耳机掏手机切首歌，因为手臂晃动直接跳去第三方广告页",
            painEn: "Walking or jogging triggers shake-ads when switching tracks",
            stepsZh: [
                "在 iPhone【设置 → 隐私与安全性 → 运动与健身】关闭音乐软件传感器权限",
                "打开音乐软件侧边栏【设置】→【消息和隐私设置】→【个人隐私设置】关闭个性化广告"
            ],
            stepsEn: [
                "Disable Motion sensor access for your music app in iOS Settings",
                "In app: Settings → Message & Privacy → Turn OFF Personalized Ads"
            ],
            searchKeywordZh: "消息和隐私设置",
            searchKeywordEn: "Privacy Settings",
            isFreeTier: false,
            opensSystemSettings: true,
            autoResetsDays: nil,
            weight: 2
        ),
        AuditItem(
            id: "pro_xianyu_ad",
            category: .shakeAd,
            symbolName: "tag.fill",
            titleZh: "闲置二手平台：关闭摇一摇与消息营销打扰",
            titleEn: "Secondhand Market: Stop Shake-Ads & Promo Chats",
            painZh: "以为买家来询价点开全是活动通知，拿起手机就触发扭一扭跳主站",
            painEn: "Stops twist-to-jump redirects and fake inquiry promo alerts",
            stepsZh: [
                "打开【我的】→ 右上角齿轮【设置】→【隐私】→【广告管理】关闭个性化广告",
                "退回【设置】→【新消息通知】关闭「活动与攻略推送」"
            ],
            stepsEn: [
                "Open Mine → Settings → Privacy → Ad Management → Turn OFF",
                "Go to Notifications and mute Promo & Campaign alerts"
            ],
            searchKeywordZh: "广告管理",
            searchKeywordEn: "Ad Management",
            isFreeTier: false,
            opensSystemSettings: false,
            autoResetsDays: nil,
            weight: 2
        ),
        AuditItem(
            id: "pro_didi_ele",
            category: .listeningAd,
            symbolName: "car.fill",
            titleZh: "打车出行软件：关闭行程页借贷与第三方卡券广告",
            titleEn: "Ride-Hailing App: Disable Loan & Coupon Popups",
            painZh: "赶时间叫车时弹窗推车主贷/消费贷，锁屏通知推优惠券",
            painEn: "Silences loan banners and promotional lock-screen pushes",
            stepsZh: [
                "打开侧边栏或【我的】→【设置】→【隐私】→【权限管理】",
                "找到【个性化推荐与广告】设为关闭，并关掉营销短信/通知开关"
            ],
            stepsEn: [
                "Open Settings → Privacy → Permissions",
                "Turn OFF Personalized Ads & Marketing Notifications"
            ],
            searchKeywordZh: "个性化推荐与广告",
            searchKeywordEn: "Personalized Ads",
            isFreeTier: false,
            opensSystemSettings: false,
            autoResetsDays: nil,
            weight: 2
        ),
        AuditItem(
            id: "pro_ctrip_travel",
            category: .listeningAd,
            symbolName: "airplane",
            titleZh: "订票酒店软件：防大数据杀熟追踪与金融推销",
            titleEn: "Travel & Hotel App: Reduce Price-Tracking Signals",
            painZh: "多查两次同一航班酒店后频繁收到催单弹窗与借钱分期广告",
            painEn: "Limits cross-session tracking signals and credit installment ads",
            stepsZh: [
                "打开【我的】→ 右上角【设置】→【隐私设置】",
                "关闭【个性化内容推荐】与【程序化广告设置】，并在系统设置禁止其跨站跟踪"
            ],
            stepsEn: [
                "Open Account → Settings → Privacy Settings",
                "Turn OFF Personalized Content & Programmatic Ads"
            ],
            searchKeywordZh: "程序化广告",
            searchKeywordEn: "Programmatic Ads",
            isFreeTier: false,
            opensSystemSettings: false,
            autoResetsDays: nil,
            weight: 2
        ),
        AuditItem(
            id: "pro_kuaishou_ad",
            category: .listeningAd,
            symbolName: "video.bubble.fill",
            titleZh: "老铁短视频平台：关闭个性化广告与通讯录关联",
            titleEn: "Live Video App: Disable Ad Profiling & Contact Sync",
            painZh: "长辈手机最容易误点直播间福袋抽奖扣费与广告下载",
            painEn: "Protects family phones from targeted ad funnels",
            stepsZh: [
                "打开左上角三条杠【设置】→【隐私设置】",
                "关闭【允许通过手机号找到我】，拉到底进【管理个性化广告】关闭开关"
            ],
            stepsEn: [
                "Open Menu → Settings → Privacy Settings",
                "Disable Phone Lookup and turn OFF Personalized Ads"
            ],
            searchKeywordZh: "管理个性化广告",
            searchKeywordEn: "Personalized Ads",
            isFreeTier: false,
            opensSystemSettings: false,
            autoResetsDays: nil,
            weight: 2
        ),
        AuditItem(
            id: "pro_local_network",
            category: .systemTrack,
            symbolName: "wifi.exclamationmark",
            titleZh: "iOS 封禁无关 App 扫描「本地局域网设备」",
            titleEn: "Block Apps from Scanning Home Wi-Fi Devices",
            painZh: "普通资讯/购物软件扫描家里路由器型号、智能电视判断家庭消费力",
            painEn: "Apps probe your Wi-Fi router and smart TVs to profile household income",
            stepsZh: [
                "打开 iPhone【设置】→【隐私与安全性】→【本地网络】",
                "除投屏视频与智能家居管理 App 外，其余软件一律关掉"
            ],
            stepsEn: [
                "Open Settings → Privacy & Security → Local Network",
                "Disable access for all apps except AirPlay/Cast and smart-home controllers"
            ],
            searchKeywordZh: "本地网络",
            searchKeywordEn: "Local Network",
            isFreeTier: false,
            opensSystemSettings: true,
            autoResetsDays: nil,
            weight: 3
        ),
        AuditItem(
            id: "pro_photo_limited",
            category: .systemTrack,
            symbolName: "photo.on.rectangle.angled",
            titleZh: "将社交/购物 App 相册权限降级为「受限访问」",
            titleEn: "Restrict Photo Library Access to Selected Only",
            painZh: "一旦给了「完全访问」，软件可在后台读取截图里的身份证、账单和聊天记录",
            painEn: "Full Photo access lets apps scan screenshots of IDs, bills, and chats",
            stepsZh: [
                "打开 iPhone【设置】→【隐私与安全性】→【照片】",
                "检查给出「完全访问」的软件，逐一改为【受限访问】或【仅添加照片】"
            ],
            stepsEn: [
                "Open Settings → Privacy & Security → Photos",
                "Downgrade apps from 'Full Access' to 'Limited Access' or 'Add Photos Only'"
            ],
            searchKeywordZh: "照片",
            searchKeywordEn: "Photos",
            isFreeTier: false,
            opensSystemSettings: true,
            autoResetsDays: nil,
            weight: 3
        ),
        AuditItem(
            id: "pro_mail_pixel",
            category: .systemTrack,
            symbolName: "envelope.badge.shield.half.filled.fill",
            titleZh: "开启邮件「保护邮件活动」拦截隐形追踪像素",
            titleEn: "Enable Mail Privacy Protection (Block Spy Pixels)",
            painZh: "营销邮件内嵌 1×1 透明图片，你一打开对方就知道你的真机 IP 和阅读时间",
            painEn: "Marketing emails embed 1px trackers to log your IP and open time",
            stepsZh: [
                "打开 iPhone【设置】→【App】→【邮件】→【隐私保护】",
                "开启【保护邮件活动】（自动隐藏 IP 并后台代理加载远端图像）"
            ],
            stepsEn: [
                "Open Settings → Apps → Mail → Privacy Protection",
                "Turn ON 'Protect Mail Activity'"
            ],
            searchKeywordZh: "隐私保护",
            searchKeywordEn: "Privacy Protection",
            isFreeTier: false,
            opensSystemSettings: true,
            autoResetsDays: nil,
            weight: 2
        ),
        AuditItem(
            id: "pro_inapp_rating_spam",
            category: .systemTrack,
            symbolName: "bell.slash.fill",
            titleZh: "统一清退垃圾营销通知与 App 内弹窗打扰",
            titleEn: "Silence Notification Spam & Rating Popups",
            painZh: "通知中心每天几十条借钱、签到、领券红点，工作时频频亮屏打断",
            painEn: "Stops daily promo push clutter and incessant popup prompts",
            stepsZh: [
                "打开 iPhone【设置】→【App】→【App Store】→ 关闭【App 内评分及评论】减少弹窗",
                "打开【设置】→【通知】将非即时通讯软件改为「定时摘要」或直接关闭通知"
            ],
            stepsEn: [
                "Open Settings → Apps → App Store → Turn OFF In-App Ratings & Reviews",
                "Move shopping/news apps into Scheduled Summary under Notifications"
            ],
            searchKeywordZh: "通知",
            searchKeywordEn: "Notifications",
            isFreeTier: false,
            opensSystemSettings: true,
            autoResetsDays: nil,
            weight: 2
        )
    ]
}
