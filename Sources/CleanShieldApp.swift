import SwiftUI

@main
struct CleanShieldApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var storeManager = StoreManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let args = ProcessInfo.processInfo.arguments
        if let langIdx = args.firstIndex(of: "--lang"), langIdx + 1 < args.count {
            UserDefaults(suiteName: SharedConstants.appGroupID)?.set(args[langIdx + 1], forKey: "app_lang")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .environmentObject(storeManager)
                .onAppear {
                    applyLaunchArgumentsIfNeeded()
                }
                .onOpenURL { url in
                    appState.handleDeepLink(url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        appState.refreshSafariExtensionState()
                    }
                }
                .onChange(of: storeManager.isProUnlocked) { _, isPro in
                    appState.syncRulesAndReloadBlocker(isPro: isPro)
                }
                .sheet(isPresented: $appState.showPaywall) {
                    PaywallSheet()
                        .environmentObject(appState)
                        .environmentObject(storeManager)
                }
                .overlay(alignment: .top) {
                    if let toast = appState.toastMessage {
                        Text(toast)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.84), in: Capsule())
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.spring(duration: 0.3), value: appState.toastMessage)
        }
    }

    private func applyLaunchArgumentsIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        if let langIdx = args.firstIndex(of: "--lang"), langIdx + 1 < args.count {
            appState.lang = (args[langIdx + 1].lowercased().hasPrefix("en") ? .en : .zh)
        }
        if let tabIdx = args.firstIndex(of: "--tab"), tabIdx + 1 < args.count,
           let tab = Int(args[tabIdx + 1]) {
            appState.selectedTab = tab
        }
        if args.contains("--demo-progress") {
            appState.completedAuditIDs = [
                "ios_motion_restrict", "ios_att_tracking", "ios_apple_ad",
                "ios_pasteboard", "ios_safari_privacy", "app_chat_ad_6m", "app_shop_tb"
            ]
            appState.safariExtensionEnabled = true
        }
        if args.contains("--show-paywall") {
            appState.presentPaywall(
                reason: appState.lang == .zh
                    ? "已为您定位本机剩余 20 项深藏摇一摇与监听开关 · 一键全量解锁"
                    : "20 deep-hidden ad & tracking switches found · Unlock full CleanShield"
            )
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var storeManager: StoreManager

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            AuditView()
                .tabItem {
                    Label(
                        appState.lang == .zh ? "关广告体检" : "Privacy Audit",
                        systemImage: "checkmark.shield.fill"
                    )
                }
                .tag(0)

            SafariShieldView()
                .tabItem {
                    Label(
                        appState.lang == .zh ? "网页净盾" : "Web Shield",
                        systemImage: "safari.fill"
                    )
                }
                .tag(1)

            ToolsView()
                .tabItem {
                    Label(
                        appState.lang == .zh ? "抹隐私·直达" : "Clean Tools",
                        systemImage: "sparkles.rectangle.stack.fill"
                    )
                }
                .tag(2)

            SettingsProView()
                .tabItem {
                    Label(
                        appState.lang == .zh ? "净盾 Pro" : "Pro & Info",
                        systemImage: "crown.fill"
                    )
                }
                .tag(3)
        }
        .tint(Color(red: 0.06, green: 0.68, blue: 0.48))
    }
}
