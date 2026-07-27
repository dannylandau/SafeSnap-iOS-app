import SwiftUI

struct RedeemCodeView: View {
    @ObservedObject var premiumManager: PremiumManager
    var onDismiss: (() -> Void)? = nil
    @State private var isRestoring = false
    @State private var isPurchasing = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "ticket.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Welcome to Archie")
                .font(.title.bold())

            Text("Redeem your VIP invite code to unlock full access.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                premiumManager.redeemCode()
            } label: {
                Text("Redeem Code")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .buttonBorderShape(.capsule)
            .padding(.horizontal, 32)

            VStack(spacing: 12) {
                Text("Or subscribe")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Button {
                        isPurchasing = true
                        Task {
                            _ = await premiumManager.purchaseMonthly()
                            isPurchasing = false
                        }
                    } label: {
                        Text("Monthly $9.99")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button {
                        isPurchasing = true
                        Task {
                            _ = await premiumManager.purchaseYearly()
                            isPurchasing = false
                        }
                    } label: {
                        Text("Yearly $99.99")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .padding(.horizontal, 32)
            }
            .disabled(isPurchasing)
            .overlay { if isPurchasing { ProgressView() } }

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

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onChange(of: premiumManager.isPremium) { _, newValue in
            if newValue { onDismiss?() }
        }
    }
}
