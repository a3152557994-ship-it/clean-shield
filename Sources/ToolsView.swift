import PhotosUI
import SwiftUI
import UIKit

struct ToolsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var storeManager: StoreManager

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoReport: PhotoPrivacyReport?
    @State private var scrubbedData: Data?
    @State private var previewImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    photoScrubberCard
                    quickLaunchGridCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(appState.lang == .zh ? "发图抹隐私 · 一步直达" : "Privacy Scrubber & Launch")
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            self.previewImage = UIImage(data: data)
                            self.photoReport = PhotoPrivacyScrubber.inspect(imageData: data)
                            self.scrubbedData = PhotoPrivacyScrubber.stripMetadata(from: data)
                        }
                    }
                }
            }
        }
    }

    private var photoScrubberCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "location.magnifyingglass")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color(red: 0.06, green: 0.65, blue: 0.46), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.lang == .zh ? "发原图前 · 一键抹除定位与拍摄信息" : "Photo GPS & EXIF Privacy Scrubber")
                        .font(.headline)
                    Text(appState.lang == .zh ? "微信发原图/网盘传图会附带精确到门牌号的经纬度" : "Original photos expose your home GPS coordinates & device model")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack {
                    Image(systemName: "photo.badge.plus")
                    Text(appState.lang == .zh ? "从相册选一张照片检测隐藏隐私（免费）" : "Select Photo to Inspect & Strip Metadata (Free)")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(red: 0.06, green: 0.65, blue: 0.46), in: RoundedRectangle(cornerRadius: 12))
            }

            if let report = photoReport {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if let img = previewImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(
                                report.riskCount > 0
                                    ? (appState.lang == .zh ? "⚠️ 检出 \(report.riskCount) 项敏感元数据！" : "⚠️ Found \(report.riskCount) Hidden Privacy Fields!")
                                    : (appState.lang == .zh ? "✓ 该照片非常干净，无定位残留" : "✓ Clean photo — No GPS or EXIF found")
                            )
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(report.riskCount > 0 ? .red : .green)

                            if report.hasGPS, let lat = report.latitude, let lon = report.longitude {
                                Text(String(format: "📍 GPS: %.4f, %.4f", lat, lon))
                                    .font(.caption.monospaced())
                            }
                            if let dev = report.deviceModel ?? report.lensModel {
                                Text("📱 \(dev)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let ts = report.captureTimestamp {
                                Text("🕒 \(ts)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }

                    if let cleanBytes = scrubbedData, let cleanUIImage = UIImage(data: cleanBytes) {
                        HStack(spacing: 10) {
                            Button {
                                UIImageWriteToSavedPhotosAlbum(cleanUIImage, nil, nil, nil)
                                appState.showToast(
                                    appState.lang == .zh
                                        ? "✓ 已保存无定位纯净副本至系统相册！"
                                        : "✓ Saved clean GPS-free copy to Photos!"
                                )
                            } label: {
                                Label(
                                    appState.lang == .zh ? "保存抹除定位后的纯净图" : "Save Clean Photo",
                                    systemImage: "arrow.down.doc.fill"
                                )
                                .font(.caption.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                            }
                            .buttonStyle(.borderedProminent)

                            ShareLink(
                                item: Image(uiImage: cleanUIImage),
                                preview: SharePreview(appState.lang == .zh ? "无隐私纯净照片" : "Clean Photo", image: Image(uiImage: cleanUIImage))
                            ) {
                                Label(appState.lang == .zh ? "直接安全分享" : "Safe Share", systemImage: "square.and.arrow.up")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var quickLaunchGridCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(appState.lang == .zh ? "一步直达台 & 桌面小组件" : "Clean Direct-Launch & Widget")
                        .font(.headline)
                    Text(
                        appState.lang == .zh
                            ? "直奔扫码/付款码/搜索框，少看无关信息流（长按桌面添加「净盾」小组件）"
                            : "Jump straight to scanners, transit passes & search bars from your Home Screen"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }

            let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(QuickLaunchCatalog.presets) { item in
                    let isPinned = appState.pinnedShortcutIDs.contains(item.id)
                    let locked = !item.isFreeTier && !storeManager.isProUnlocked

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: item.symbolName)
                                .font(.headline)
                                .foregroundStyle(Color(red: 0.06, green: 0.65, blue: 0.46))
                            Spacer()
                            Button {
                                appState.togglePinnedShortcut(item, isPro: storeManager.isProUnlocked)
                            } label: {
                                Image(systemName: locked ? "lock.fill" : (isPinned ? "pin.fill" : "pin"))
                                    .font(.caption)
                                    .foregroundStyle(locked ? .orange : (isPinned ? Color(red: 0.06, green: 0.65, blue: 0.46) : .secondary))
                                    .padding(6)
                                    .background(Color(.tertiarySystemFill), in: Circle())
                            }
                        }

                        Button {
                            if locked {
                                appState.presentPaywall(
                                    reason: appState.lang == .zh
                                        ? "解锁「\(item.titleZh)」及桌面 8 宫格快捷小组件"
                                        : "Unlock '\(item.titleEn)' & 8-slot Home Screen Widget"
                                )
                            } else {
                                openShortcut(item)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title(appState.lang))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.primary)
                                Text(item.subtitle(appState.lang))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func openShortcut(_ item: QuickLaunchItem) {
        if item.urlScheme == "cleanshield://open-settings" {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            return
        }
        guard let url = URL(string: item.urlScheme) else { return }
        UIApplication.shared.open(url) { ok in
            if !ok {
                appState.showToast(
                    appState.lang == .zh
                        ? "本机未安装对应应用，已在支持设备生效"
                        : "Target app not installed on this device"
                )
            }
        }
    }
}
