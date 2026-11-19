import Foundation
import StoreKit

@MainActor
public final class StoreManager: ObservableObject {
    @Published public private(set) var products: [String: Product] = [:]
    @Published public private(set) var isProUnlocked: Bool = false
    @Published public private(set) var isLoading: Bool = false
    @Published public var statusMessage: String?

    private let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) ?? .standard
    private var updatesTask: Task<Void, Never>?

    public let productIDs: [String] = [
        SharedConstants.monthlyProductID,
        SharedConstants.yearlyProductID,
        SharedConstants.lifetimeProductID
    ]

    public init() {
        self.isProUnlocked = defaults.bool(forKey: SharedConstants.isProUnlockedKey)
        self.updatesTask = observeTransactionUpdates()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    public func loadProducts() async {
        do {
            let fetched = try await Product.products(for: productIDs)
            var map: [String: Product] = [:]
            for p in fetched {
                map[p.id] = p
            }
            self.products = map
        } catch {
            // Offline or pre-review fallback pricing displayed cleanly
        }
    }

    public func displayPrice(for id: String, lang: AppLang) -> String {
        if let product = products[id] {
            return product.displayPrice
        }
        switch (id, lang) {
        case (SharedConstants.monthlyProductID, .zh): return "¥3.00"
        case (SharedConstants.monthlyProductID, .en): return "$0.99"
        case (SharedConstants.yearlyProductID, .zh): return "¥12.00"
        case (SharedConstants.yearlyProductID, .en): return "$3.99"
        case (SharedConstants.lifetimeProductID, .zh): return "¥25.00"
        case (SharedConstants.lifetimeProductID, .en): return "$6.99"
        default: return lang == .zh ? "¥25.00" : "$6.99"
        }
    }

    public func purchase(_ productID: String, lang: AppLang) async -> Bool {
        isLoading = true
        statusMessage = nil
        defer { isLoading = false }

        if products[productID] == nil {
            await loadProducts()
        }
        guard let product = products[productID] else {
            statusMessage = lang == .zh
                ? "正在连接 App Store 商品服务，请确认网络畅通后重试。"
                : "Connecting to App Store billing. Please check network and retry."
            return false
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let tx) = verification {
                    await tx.finish()
                    unlockPro()
                    statusMessage = lang == .zh ? "🎉 已成功解锁净盾 Pro 全部权益！" : "🎉 CleanShield Pro unlocked!"
                    return true
                } else {
                    statusMessage = lang == .zh ? "订单校验未通过，请稍后重试。" : "Purchase verification failed."
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                statusMessage = lang == .zh ? "订单等待家长或系统确认中。" : "Purchase pending approval."
                return false
            @unknown default:
                return false
            }
        } catch {
            statusMessage = error.localizedDescription
            return false
        }
    }

    public func restorePurchases(lang: AppLang) async {
        isLoading = true
        statusMessage = nil
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if isProUnlocked {
                statusMessage = lang == .zh ? "✓ 已成功恢复您的 Pro 权益！" : "✓ Your Pro access has been restored!"
            } else {
                statusMessage = lang == .zh ? "当前 Apple ID 未查询到历史有效订单。" : "No active Pro purchases found for this Apple ID."
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               productIDs.contains(tx.productID),
               tx.revocationDate == nil {
                unlocked = true
                break
            }
        }
        if unlocked {
            unlockPro()
        }
    }

    private func unlockPro() {
        isProUnlocked = true
        defaults.set(true, forKey: SharedConstants.isProUnlockedKey)
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    await tx.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
    }
}
