import SwiftUI
import WidgetKit

struct CleanShieldEntry: TimelineEntry {
    let date: Date
    let lang: AppLang
    let hygieneScore: Int
    let shortcuts: [QuickLaunchItem]
}

struct CleanShieldProvider: TimelineProvider {
    func placeholder(in context: Context) -> CleanShieldEntry {
        CleanShieldEntry(
            date: Date(),
            lang: .zh,
            hygieneScore: 92,
            shortcuts: Array(QuickLaunchCatalog.presets.prefix(4))
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CleanShieldEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CleanShieldEntry>) -> Void) {
        let entry = loadEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> CleanShieldEntry {
        let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) ?? .standard
        let lang = AppLang.current
        let completed = Set(defaults.stringArray(forKey: SharedConstants.completedAuditIDsKey) ?? [])
        let score = AuditCatalog.calculateScore(completedIDs: completed)
        let pinnedIDs = defaults.stringArray(forKey: SharedConstants.pinnedShortcutsKey) ?? ["wx_scan", "ali_scan", "ali_paycode", "sys_settings"]
        let resolved = pinnedIDs.compactMap { id in QuickLaunchCatalog.presets.first(where: { $0.id == id }) }
        let fallback = resolved.isEmpty ? Array(QuickLaunchCatalog.presets.prefix(4)) : resolved
        return CleanShieldEntry(date: Date(), lang: lang, hygieneScore: score, shortcuts: Array(fallback.prefix(4)))
    }
}

struct CleanShieldWidgetEntryView: View {
    var entry: CleanShieldProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        default:
            mediumView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(Color(red: 0.25, green: 0.95, blue: 0.68))
                Text(entry.lang == .zh ? "净盾" : "CleanShield")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
            }

            Spacer(minLength: 0)

            Text("\(entry.hygieneScore)")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(entry.lang == .zh ? "隐私清净分 · 零上传" : "Privacy Score")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))

            if let first = entry.shortcuts.first, let url = URL(string: first.urlScheme) {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Image(systemName: first.symbolName)
                        Text(first.title(entry.lang))
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 0.04, green: 0.22, blue: 0.17))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.32, green: 0.95, blue: 0.72), in: Capsule())
                }
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.24, blue: 0.20), Color(red: 0.07, green: 0.14, blue: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(Color(red: 0.25, green: 0.95, blue: 0.68))
                Text(entry.lang == .zh ? "净盾 · 一步直达免打扰台" : "CleanShield Direct Launch")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text(entry.lang == .zh ? "清净分 \(entry.hygieneScore)" : "Score \(entry.hygieneScore)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color(red: 0.30, green: 0.96, blue: 0.72))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.12), in: Capsule())
            }

            HStack(spacing: 8) {
                ForEach(entry.shortcuts) { item in
                    if let url = URL(string: item.urlScheme) {
                        Link(destination: url) {
                            VStack(spacing: 6) {
                                Image(systemName: item.symbolName)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Color(red: 0.30, green: 0.96, blue: 0.72))
                                Text(item.title(entry.lang))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.24, blue: 0.20), Color(red: 0.07, green: 0.14, blue: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

@main
struct CleanShieldWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CleanShieldDirectWidget()
    }
}

struct CleanShieldDirectWidget: Widget {
    let kind: String = "CleanShieldDirectWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CleanShieldProvider()) { entry in
            CleanShieldWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("净盾 · 一步直达与清净分")
        .description("跳过繁杂信息流，桌面一步呼出扫码、付款码与隐私体检。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
