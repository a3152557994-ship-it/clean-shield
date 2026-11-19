import Foundation

/// Generates valid Apple WebKit SFContentBlocker JSON rules with strict ordering:
/// 1) Ad network domain & cosmetic banner blocks
/// 2) Third-party tracker & pixel blocks
/// 3) Pro anti-jump & sticky app-download overlay cosmetic blocks
/// 4) Custom user blocked domains
/// 5) LAST: Iron Whitelist (`ignore-previous-rules`) for maps, banking, carriers, payment & user whitelist
public enum BlockerRuleCompiler {

    public static let adDomains: [String] = [
        "doubleclick.net",
        "googlesyndication.com",
        "googleadservices.com",
        "adnxs.com",
        "taboola.com",
        "outbrain.com",
        "criteo.com",
        "pubmatic.com",
        "rubiconproject.com",
        "openx.net",
        "popads.net",
        "popcash.net",
        "propellerads.com",
        "exoclick.com",
        "juicyads.com",
        "pos.baidu.com",
        "cpro.baidustatic.com",
        "cbjs.baidu.com",
        "eclick.baidu.com",
        "tanx.com",
        "mmstat.com",
        "allyes.com",
        "mediav.com",
        "adsmogo.com",
        "inmobi.com",
        "vungle.com",
        "applovin.com",
        "unityads.unity3d.com",
        "pangolin-sdk-toutiao.com",
        "pglstatp-toutiao.com"
    ]

    public static let trackerDomains: [String] = [
        "google-analytics.com",
        "googletagmanager.com",
        "hotjar.com",
        "clarity.ms",
        "mixpanel.com",
        "segment.io",
        "amplitude.com",
        "appsflyer.com",
        "adjust.com",
        "branch.io",
        "scorecardresearch.com",
        "quantserve.com",
        "hm.baidu.com",
        "umeng.com",
        "umengcloud.com",
        "growingio.com",
        "sensorsdata.cn",
        "miaozhen.com",
        "admaster.com.cn",
        "talkingdata.com",
        "cnzz.com"
    ]

    public static let cosmeticAdSelectors: [String] = [
        ".ad-banner",
        ".ads-banner",
        ".adsbygoogle",
        ".floating-ad",
        ".popup-ad",
        ".bottom-ad-banner",
        ".top-ad-banner",
        "[id^='div-gpt-ad']",
        "[class*='ad-slot-']",
        "[class*='sponsor-banner']"
    ]

    public static let antiJumpProSelectors: [String] = [
        ".open-in-app-banner",
        ".open-app-bar",
        ".download-app-bar",
        ".call-app-btn",
        ".jump-to-app",
        ".read-more-mask-app",
        "[class*='openInApp']",
        "[class*='open-in-app']",
        "[class*='downloadAppBanner']",
        "[id*='open-app-banner']"
    ]

    /// Essential services guaranteed NEVER to be broken by content blocking (solves #1 competitor 1-star complaint).
    public static let ironWhitelistDomains: [String] = [
        "amap.com",
        "autonavi.com",
        "map.baidu.com",
        "bdimg.com",
        "10086.cn",
        "10010.com",
        "189.cn",
        "icbc.com.cn",
        "ccb.com",
        "cmbchina.com",
        "abchina.com",
        "boc.cn",
        "psbc.com",
        "bankcomm.com",
        "unionpay.com",
        "95516.com",
        "tenpay.com",
        "pay.weixin.qq.com",
        "alipay.com",
        "alipayobjects.com",
        "12306.cn",
        "gov.cn",
        "apple.com",
        "icloud.com",
        "mzstatic.com",
        "cdn-apple.com"
    ]

    public static func sanitizeDomain(_ raw: String) -> String? {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cleaned.hasPrefix("https://") { cleaned.removeFirst(8) }
        if cleaned.hasPrefix("http://") { cleaned.removeFirst(7) }
        if cleaned.hasPrefix("www.") { cleaned.removeFirst(4) }
        if let slashIdx = cleaned.firstIndex(of: "/") {
            cleaned = String(cleaned[..<slashIdx])
        }
        guard cleaned.contains("."),
              cleaned.count >= 4,
              cleaned.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" }) else {
            return nil
        }
        return cleaned
    }

    public static func domainFilterRegex(for domain: String) -> String {
        let escaped = domain.replacingOccurrences(of: ".", with: "\\.")
        return "^https?://([a-z0-9-]+\\.)*\(escaped)(/|:|$)"
    }

    public static func compileRules(config: ShieldBlockerConfig, isPro: Bool) -> [[String: Any]] {
        var rules: [[String: Any]] = []

        if config.blockWebAds {
            for domain in adDomains {
                rules.append([
                    "trigger": [
                        "url-filter": domainFilterRegex(for: domain),
                        "load-type": ["third-party"]
                    ],
                    "action": [
                        "type": "block"
                    ]
                ])
            }
            rules.append([
                "trigger": [
                    "url-filter": "^https?://.*"
                ],
                "action": [
                    "type": "css-display-none",
                    "selector": cosmeticAdSelectors.joined(separator: ", ")
                ]
            ])
        }

        if config.blockTrackers {
            for domain in trackerDomains {
                rules.append([
                    "trigger": [
                        "url-filter": domainFilterRegex(for: domain),
                        "load-type": ["third-party"]
                    ],
                    "action": [
                        "type": "block"
                    ]
                ])
            }
        }

        if isPro && config.blockJumpBannersPro {
            rules.append([
                "trigger": [
                    "url-filter": "^https?://.*"
                ],
                "action": [
                    "type": "css-display-none",
                    "selector": antiJumpProSelectors.joined(separator: ", ")
                ]
            ])
        }

        if isPro {
            for rawDomain in config.customBlockedDomains {
                if let dom = sanitizeDomain(rawDomain) {
                    rules.append([
                        "trigger": [
                            "url-filter": domainFilterRegex(for: dom)
                        ],
                        "action": [
                            "type": "block"
                        ]
                    ])
                }
            }
        }

        // Fallback safety rule so WebKit never rejects an empty array if user toggles everything off
        if rules.isEmpty {
            rules.append([
                "trigger": [
                    "url-filter": "^https?://cleanshield-noop\\.invalid/"
                ],
                "action": [
                    "type": "block"
                ]
            ])
        }

        // CRITICAL: Iron Whitelist MUST be appended LAST so `ignore-previous-rules` overrides everything above
        var whitelist: [String] = config.enableIronWhitelist ? ironWhitelistDomains : []
        if isPro {
            for raw in config.customWhitelistDomains {
                if let dom = sanitizeDomain(raw), !whitelist.contains(dom) {
                    whitelist.append(dom)
                }
            }
        }

        if !whitelist.isEmpty {
            let prefixedDomains = whitelist.map { "*\($0)" }
            rules.append([
                "trigger": [
                    "url-filter": ".*",
                    "if-domain": prefixedDomains
                ],
                "action": [
                    "type": "ignore-previous-rules"
                ]
            ])
            for dom in whitelist {
                rules.append([
                    "trigger": [
                        "url-filter": domainFilterRegex(for: dom)
                    ],
                    "action": [
                        "type": "ignore-previous-rules"
                    ]
                ])
            }
        }

        return rules
    }

    public static func compileJSONData(config: ShieldBlockerConfig, isPro: Bool) throws -> Data {
        let rules = compileRules(config: config, isPro: isPro)
        return try JSONSerialization.data(withJSONObject: rules, options: [.prettyPrinted, .sortedKeys])
    }

    @discardableResult
    public static func writeToSharedContainer(config: ShieldBlockerConfig, isPro: Bool) throws -> URL {
        let data = try compileJSONData(config: config, isPro: isPro)
        let baseURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedConstants.appGroupID)
            ?? FileManager.default.temporaryDirectory
        let fileURL = baseURL.appendingPathComponent(SharedConstants.compiledRulesFilename)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
