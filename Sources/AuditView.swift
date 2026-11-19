import SwiftUI
import UIKit

struct AuditView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var storeManager: StoreManager

    @State private var selectedCategory: AuditCategory = .all
    @State private var expandedItemID: String? = "ios_motion_restrict"

    private var filteredItems: [AuditItem] {
        AuditCatalog.items.filter { item in
            selectedCategory == .all || item.category == selectedCategory
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    hygieneHeroCard
                    categoryFilterBar

                    VStack(spacing: 12) {
                        ForEach(filteredItems) { item in
                            AuditItemCard(
                                item: item,
                                isCompleted: appState.completedAuditIDs.contains(item.id),
                                isExpanded: expandedItemID == item.id,
                                isPro: storeManager.isProUnlocked,
                                reminderDate: appState.reminderDates[item.id],
                                lang: appState.lang,
                                onTapHeader: {
                                    if !item.isFreeTier && !storeManager.isProUnlocked {
                                        appState.presentPaywall(
                                            reason: appState.lang == .zh
                                                ? "解锁「\(item.titleZh)」及全部 20 项深藏开关一步到位路线图"
                                                : "Unlock '\(item.titleEn)' & all 20+ deep-app guides"
                                        )
                                    } else {
                                        withAnimation(.snappy(duration: 0.25)) {
                                            expandedItemID = (expandedItemID == item.id) ? nil : item.id
                                        }
                                    }
                                },
                                onToggleComplete: {
                                    appState.toggleAuditCompleted(item, isPro: storeManager.isProUnlocked)
                                },
                                onCopyKeyword: {
                                    UIPasteboard.general.string = item.searchKeyword(appState.lang)
                                    appState.showToast(
                                        appState.lang == .zh
                                            ? "已复制「\(item.searchKeyword(.zh))」，去设置顶栏粘贴即达"
                                            : "Copied '\(item.searchKeyword(.en))'"
                                    )
                                },
                                onOpenSettings: {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                },
                                onScheduleReminder: {
                                    appState.schedule180DayReminder(for: item)
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(appState.lang == .zh ? "净盾 · 防监听与关广告" : "CleanShield Audit")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.lang = (appState.lang == .zh ? .en : .zh)
                    } label: {
                        Text(appState.lang == .zh ? "EN" : "中文")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.secondarySystemFill), in: Capsule())
                    }
                }
            }
        }
    }

    private var hygieneHeroCard: some View {
        let score = appState.hygieneScore
        let completed = appState.completedAuditIDs.count
        let total = AuditCatalog.items.count

        return HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 10)
                    .frame(width: 86, height: 86)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100.0)
                    .stroke(
                        AngularGradient(
                            colors: [Color(red: 0.25, green: 0.95, blue: 0.68), Color(red: 0.12, green: 0.82, blue: 0.95)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 86, height: 86)
                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(appState.lang == .zh ? "清净分" : "SCORE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(Color(red: 0.30, green: 0.96, blue: 0.72))
                    Text(appState.lang == .zh ? "100% 纯离线本地体检" : "100% Offline On-Device Audit")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(red: 0.30, green: 0.96, blue: 0.72))
                }

                Text(
                    appState.lang == .zh
                        ? "已关停 \(completed)/\(total) 个广告与追踪入口"
                        : "\(completed)/\(total) Ad & Privacy Switches Closed"
                )
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

                Text(
                    appState.lang == .zh
                        ? "告别走路摇一摇乱跳购物页、聊啥推啥与半年自动复活"
                        : "Stop shake-to-jump redirects, ad profiling & silent 180-day resets"
                )
                .font(.caption)
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

                if !storeManager.isProUnlocked {
                    Button {
                        appState.presentPaywall(
                            reason: appState.lang == .zh
                                ? "本机还有 \(appState.uncheckedCount) 个深藏摇一摇与监听开关待清理"
                                : "\(appState.uncheckedCount) deep-hidden ad & tracking switches remaining"
                        )
                    } label: {
                        Text(appState.lang == .zh ? "一键解锁全部 30 项清净方案 →" : "Unlock All 30 Guides →")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color(red: 0.04, green: 0.22, blue: 0.17))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.32, green: 0.95, blue: 0.72), in: Capsule())
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.23, blue: 0.20), Color(red: 0.08, green: 0.14, blue: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AuditCategory.allCases, id: \.rawValue) { cat in
                    let active = (selectedCategory == cat)
                    Button {
                        selectedCategory = cat
                    } label: {
                        Text(cat.label(appState.lang))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(active ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                active
                                    ? AnyShapeStyle(Color(red: 0.06, green: 0.65, blue: 0.46))
                                    : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                                in: Capsule()
                            )
                    }
                }
            }
        }
    }
}

private struct AuditItemCard: View {
    let item: AuditItem
    let isCompleted: Bool
    let isExpanded: Bool
    let isPro: Bool
    let reminderDate: Date?
    let lang: AppLang
    let onTapHeader: () -> Void
    let onToggleComplete: () -> Void
    let onCopyKeyword: () -> Void
    let onOpenSettings: () -> Void
    let onScheduleReminder: () -> Void

    var body: some View {
        let locked = !item.isFreeTier && !isPro

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onToggleComplete) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : (locked ? "lock.circle.fill" : "circle"))
                        .font(.system(size: 24))
                        .foregroundStyle(
                            isCompleted
                                ? Color(red: 0.06, green: 0.68, blue: 0.48)
                                : (locked ? Color.orange : Color.secondary)
                        )
                }
                .buttonStyle(.plain)

                Button(action: onTapHeader) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Image(systemName: item.symbolName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color(red: 0.06, green: 0.65, blue: 0.46))
                            Text(item.title(lang))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(isCompleted ? .secondary : .primary)
                                .strikethrough(isCompleted)
                                .multilineTextAlignment(.leading)
                        }

                        Text(item.pain(lang))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 6) {
                            if item.isFreeTier {
                                Text(lang == .zh ? "免费必关" : "FREE CORE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color(red: 0.06, green: 0.62, blue: 0.44))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Color(red: 0.06, green: 0.68, blue: 0.48).opacity(0.14), in: Capsule())
                            } else {
                                Text("PRO")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.15), in: Capsule())
                            }

                            if let resetDays = item.autoResetsDays {
                                Text(lang == .zh ? "⚠️ 每 \(resetDays) 天自动复活" : "⚠️ Resets every \(resetDays)d")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                    Spacer(minLength: 4)
                    Image(systemName: locked ? "lock.fill" : (isExpanded ? "chevron.up" : "chevron.down"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .buttonStyle(.plain)
            }
            .padding(14)

            if isExpanded && !locked {
                Divider().padding(.horizontal, 14)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(item.steps(lang).enumerated()), id: \.offset) { idx, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(idx + 1)")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Color(red: 0.06, green: 0.65, blue: 0.46), in: Circle())
                            Text(step)
                                .font(.footnote)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(spacing: 8) {
                        Button(action: onCopyKeyword) {
                            Label(
                                lang == .zh ? "复制「\(item.searchKeyword(.zh))」" : "Copy Keyword",
                                systemImage: "doc.on.doc"
                            )
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                        }

                        if item.opensSystemSettings {
                            Button(action: onOpenSettings) {
                                Label(
                                    lang == .zh ? "打开系统设置" : "Open Settings",
                                    systemImage: "arrow.up.forward.app"
                                )
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(Color(red: 0.06, green: 0.65, blue: 0.46), in: Capsule())
                            }
                        }

                        Spacer(minLength: 0)

                        Button(action: onToggleComplete) {
                            Text(isCompleted ? (lang == .zh ? "已关停 ✓" : "Done ✓") : (lang == .zh ? "标记已关" : "Mark Done"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(isCompleted ? .secondary : Color(red: 0.06, green: 0.65, blue: 0.46))
                        }
                    }
                    .padding(.top, 2)

                    if let resetDays = item.autoResetsDays {
                        Button(action: onScheduleReminder) {
                            HStack(spacing: 6) {
                                Image(systemName: "bell.badge.fill")
                                if let date = reminderDate {
                                    Text(
                                        lang == .zh
                                            ? "已设复检提醒：\(date.formatted(date: .abbreviated, time: .omitted))"
                                            : "Reminder set for \(date.formatted(date: .abbreviated, time: .omitted))"
                                    )
                                } else {
                                    Text(
                                        lang == .zh
                                            ? "一键开启 \(resetDays) 天失效重关提醒（防悄悄复活）"
                                            : "Set \(resetDays)-Day Auto-Reset Alert"
                                    )
                                }
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(14)
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
