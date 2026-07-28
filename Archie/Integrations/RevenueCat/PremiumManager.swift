import Foundation
import RevenueCat

@MainActor
final class PremiumManager: ObservableObject {
    @Published private(set) var isPremium: Bool {
        didSet { UserDefaults.standard.set(isPremium, forKey: "com.archie.isPremiumCache") }
    }
    @Published private(set) var isLoading = true
    @Published var purchaseError: String?

    static let apiKey: String = Bundle.main.infoDictionaryValue(for: "RevenueCatAPIKey") ?? ""

    private var isConfigured: Bool { !Self.apiKey.isEmpty }

    init() {
        self.isPremium = UserDefaults.standard.bool(forKey: "com.archie.isPremiumCache")
    }

    func configure() {
        guard isConfigured else {
            print("[PremiumManager] Skipping — API key not set. App will run without premium gating.")
            isPremium = true
            isLoading = false
            return
        }
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Self.apiKey)
    }

    func identify(userId: String) async {
        guard isConfigured else { return }
        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(userId)
            isPremium = customerInfo.entitlements["premium"]?.isActive == true
        } catch {
            print("[PremiumManager] logIn failed: \(error.localizedDescription)")
        }
        isLoading = false
    }

    func logOut() {
        guard isConfigured else { return }
        isPremium = false
        isLoading = false
        Task {
            _ = try? await Purchases.shared.logOut()
        }
    }

    func checkEntitlement() async {
        guard isConfigured else { return }
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            isPremium = customerInfo.entitlements["premium"]?.isActive == true
        } catch {
            print("[PremiumManager] check failed: \(error.localizedDescription)")
        }
        isLoading = false
    }

    func redeemCode() {
        Purchases.shared.presentCodeRedemptionSheet()
    }

    static var isSandbox: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }

    func purchaseMonthly() async -> Bool {
        await purchasePackage(identifier: "$rc_monthly")
    }

    func purchaseYearly() async -> Bool {
        await purchasePackage(identifier: "$rc_annual")
    }

    private func purchasePackage(identifier: String) async -> Bool {
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let package = offerings.current?.package(identifier: identifier) else {
                purchaseError = "Subscription package not found. Please try again later."
                print("[PremiumManager] Package \(identifier) not found in offerings: \(String(describing: offerings.current))")
                return false
            }
            let result = try await Purchases.shared.purchase(package: package)
            isPremium = result.customerInfo.entitlements["premium"]?.isActive == true
            return isPremium
        } catch {
            purchaseError = error.localizedDescription
            print("[PremiumManager] Purchase failed: \(error.localizedDescription)")
            return false
        }
    }

    func grantTestAccess() {
        isPremium = true
    }

    func restorePurchases() async -> Bool {
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            isPremium = customerInfo.entitlements["premium"]?.isActive == true
            return true
        } catch {
            print("[PremiumManager] restore failed: \(error.localizedDescription)")
            return false
        }
    }
}
