import SwiftUI

struct PaywallView: View {
    @ObservedObject var premiumManager: PremiumManager
    let freeScanLimit: Int
    var onDismiss: (() -> Void)? = nil
    @State private var isRestoring = false
    @State private var isPurchasing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .padding(.top, 48)

                Text("You've used your \(freeScanLimit) free scans")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("Subscribe to Archie Premium to keep scanning products for safety.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    purchaseButton(
                        title: "Yearly \(premiumManager.yearlyPrice ?? "$99.99") / year",
                        action: premiumManager.purchaseYearly
                    )
                    purchaseButton(
                        title: "Monthly \(premiumManager.monthlyPrice ?? "$9.99") / month",
                        action: premiumManager.purchaseMonthly
                    )
                }
                .padding(.horizontal, 32)
                .disabled(isPurchasing)
                .overlay { if isPurchasing { ProgressView() } }

                Text("Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple ID. Manage or cancel anytime in your App Store account settings.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                HStack(spacing: 16) {
                    Link("Terms of Use", destination: FreeScanPolicy.termsURL)
                    Link("Privacy Policy", destination: FreeScanPolicy.privacyURL)
                }
                .font(.caption)

                Button {
                    isRestoring = true
                    Task {
                        _ = await premiumManager.restorePurchases()
                        isRestoring = false
                    }
                } label: {
                    if isRestoring {
                        ProgressView()
                    } else {
                        Text("Restore Purchases")
                            .font(.subheadline)
                    }
                }
                .foregroundColor(.secondary)

                Button("Have an invite code?") {
                    premiumManager.redeemCode()
                }
                .font(.subheadline)
                .foregroundColor(.green)

                #if DEBUG
                Button {
                    premiumManager.grantTestAccess()
                } label: {
                    Text("Tester Bypass")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.horizontal, 32)
                #endif
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onChange(of: premiumManager.isPremium) { _, newValue in
            if newValue { onDismiss?() }
        }
        .alert("Purchase Failed", isPresented: .init(
            get: { premiumManager.purchaseError != nil },
            set: { if !$0 { premiumManager.purchaseError = nil } }
        )) {
            Button("OK") { premiumManager.purchaseError = nil }
        } message: {
            Text(premiumManager.purchaseError ?? "")
        }
    }

    private func purchaseButton(title: String, action: @escaping () async -> Bool) -> some View {
        Button {
            isPurchasing = true
            Task {
                _ = await action()
                isPurchasing = false
            }
        } label: {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .buttonBorderShape(.capsule)
    }
}
