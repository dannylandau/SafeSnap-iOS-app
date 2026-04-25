import Foundation
import RevenueCat

@MainActor
final class PremiumManager: ObservableObject {
    @Published private(set) var isPremium = false
    @Published private(set) var isLoading = true

    static let apiKey: String = Bundle.main.infoDictionaryValue(for: "RevenueCatAPIKey") ?? ""

    private var isConfigured: Bool { !Self.apiKey.isEmpty }

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
        isLoading = true
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
