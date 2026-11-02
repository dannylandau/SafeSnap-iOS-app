# Free Scans Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give non-premium users N free scans (default 10) before the paywall, replacing the invite-code gate on the first scan.

**Architecture:** A pure `FreeScanCounter` (UserDefaults, per user) holds usage; `ScanTab` combines it with `PremiumManager.isPremium` to gate camera/gallery and records scans by observing `ScanViewModel.phase`. Client decisions live as constants in `FreeScanPolicy`. `PremiumManager` additionally reads the limit from RevenueCat offering metadata and StoreKit prices for the renamed `PaywallView`.

**Tech Stack:** SwiftUI, Combine, RevenueCat 5.99.2, XCTest. Spec: `docs/superpowers/specs/2026-11-02-free-scans-design.md`.

**Project notes:** Folders are Xcode file-system synchronized groups, so new files under `Archie/` and `ArchieTests/` are picked up without editing `project.pbxproj`. Tests use XCTest with `@testable import Archie`.

Test command used below:

```bash
xcodebuild test -project Archie.xcodeproj -scheme ArchieTests \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -only-testing:ArchieTests/FreeScanCounterTests 2>&1 | grep -E "Test Case|error:|\*\* TEST"
```

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `Archie/Features/FreeScans/FreeScanPolicy.swift` | Create | Client-decision constants, default limit, metadata key, legal URLs |
| `Archie/Features/FreeScans/FreeScanCounter.swift` | Create | Per-user persisted scan count, remaining/limit logic |
| `ArchieTests/FreeScanCounterTests.swift` | Create | Unit tests for the counter |
| `Archie/Integrations/RevenueCat/PremiumManager.swift` | Modify | Publish `freeScanLimit`, `monthlyPrice`, `yearlyPrice` from current offering |
| `Archie/Shared/Components/RedeemCodeView.swift` → `PaywallView.swift` | Rename + rewrite | Free-scans paywall with disclosure and legal links |
| `Archie/App/AppDependencies.swift` | Modify | Own a `FreeScanCounter` |
| `Archie/App/RootView.swift` | Modify | Scope counter to signed-in user |
| `Archie/App/Tabs/ScanTab.swift` | Modify | Gating, scan recording, status label text, limit wiring |
| `Archie/Features/Scan/Views/ScanView.swift` | Modify | Show optional free-scan status label in idle layout |

---

### Task 1: FreeScanPolicy

**Files:**
- Create: `Archie/Features/FreeScans/FreeScanPolicy.swift`

- [ ] **Step 1: Create the policy**

```swift
import Foundation

/// Client decisions for the free-scan allowance. Each constant maps to a question
/// in docs/superpowers/specs/2026-11-02-free-scans-design.md.
enum FreeScanPolicy {
    enum CountTrigger {
        /// Scan counts only when analysis returns a result.
        case successfulResult
        /// Scan counts as soon as analysis starts.
        case scanStart
    }

    /// Decision 1: when a scan uses up a free scan.
    static let countTrigger: CountTrigger = .successfulResult

    /// Decision 2: whether History is locked once free scans run out. Account is never locked.
    static let gatesHistory = false

    /// Decision 3: whether the limit comes from RevenueCat offering metadata.
    static let usesRemoteLimit = true

    static let defaultLimit = 10
    static let remoteLimitMetadataKey = "free_scan_limit"

    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyURL = URL(string: "https://archieml.com/privacy")!
}
```

- [ ] **Step 2: Commit**

```bash
git add Archie/Features/FreeScans/FreeScanPolicy.swift
git commit -m "feat: add FreeScanPolicy with pending client decisions"
```

---

### Task 2: FreeScanCounter (TDD)

**Files:**
- Create: `ArchieTests/FreeScanCounterTests.swift`
- Create: `Archie/Features/FreeScans/FreeScanCounter.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import Archie

@MainActor
final class FreeScanCounterTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "FreeScanCounterTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func makeCounter(userId: String? = "user-a", limit: Int = 10) -> FreeScanCounter {
        FreeScanCounter(defaults: defaults, userId: userId, limit: limit)
    }

    func test_newUser_hasFullAllowance() {
        let counter = makeCounter()
        XCTAssertEqual(counter.used, 0)
        XCTAssertEqual(counter.remaining, 10)
        XCTAssertTrue(counter.hasFreeScans)
    }

    func test_recordScan_decrementsRemaining() {
        let counter = makeCounter()
        counter.recordScan()
        counter.recordScan()
        XCTAssertEqual(counter.used, 2)
        XCTAssertEqual(counter.remaining, 8)
    }

    func test_recordScan_persistsAcrossInstances() {
        makeCounter().recordScan()
        XCTAssertEqual(makeCounter().used, 1)
    }

    func test_atLimit_hasNoFreeScans_andRemainingNeverNegative() {
        let counter = makeCounter(limit: 2)
        counter.recordScan()
        counter.recordScan()
        counter.recordScan()
        XCTAssertFalse(counter.hasFreeScans)
        XCTAssertEqual(counter.remaining, 0)
    }

    func test_usersAreIsolated() {
        makeCounter(userId: "user-a").recordScan()
        XCTAssertEqual(makeCounter(userId: "user-b").used, 0)
    }

    func test_setUser_reloadsCount() {
        makeCounter(userId: "user-b").recordScan()
        let counter = makeCounter(userId: "user-a")
        counter.setUser("user-b")
        XCTAssertEqual(counter.used, 1)
        counter.setUser(nil)
        XCTAssertEqual(counter.used, 0)
    }

    func test_setLimit_updatesRemaining() {
        let counter = makeCounter()
        counter.recordScan()
        counter.setLimit(3)
        XCTAssertEqual(counter.limit, 3)
        XCTAssertEqual(counter.remaining, 2)
    }

    func test_setLimit_nilOrNonPositive_fallsBackToDefault() {
        let counter = makeCounter(limit: 3)
        counter.setLimit(nil)
        XCTAssertEqual(counter.limit, FreeScanPolicy.defaultLimit)
        counter.setLimit(0)
        XCTAssertEqual(counter.limit, FreeScanPolicy.defaultLimit)
        counter.setLimit(-5)
        XCTAssertEqual(counter.limit, FreeScanPolicy.defaultLimit)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run the test command. Expected: build failure, `cannot find 'FreeScanCounter' in scope`.

- [ ] **Step 3: Implement the counter**

```swift
import Foundation

/// Tracks how many free scans the current user has used. Stored on device, per user.
@MainActor
final class FreeScanCounter: ObservableObject {
    @Published private(set) var used: Int
    @Published private(set) var limit: Int

    private let defaults: UserDefaults
    private var userId: String

    init(defaults: UserDefaults = .standard, userId: String?, limit: Int = FreeScanPolicy.defaultLimit) {
        self.defaults = defaults
        self.userId = userId ?? Self.anonymousId
        self.limit = limit > 0 ? limit : FreeScanPolicy.defaultLimit
        self.used = defaults.integer(forKey: Self.key(for: userId ?? Self.anonymousId))
    }

    var remaining: Int { max(limit - used, 0) }
    var hasFreeScans: Bool { remaining > 0 }

    func recordScan() {
        used += 1
        defaults.set(used, forKey: Self.key(for: userId))
    }

    func setUser(_ id: String?) {
        userId = id ?? Self.anonymousId
        used = defaults.integer(forKey: Self.key(for: userId))
    }

    func setLimit(_ newLimit: Int?) {
        if let newLimit, newLimit > 0 {
            limit = newLimit
        } else {
            limit = FreeScanPolicy.defaultLimit
        }
    }

    private static let anonymousId = "anonymous"

    private static func key(for userId: String) -> String {
        "com.archie.freeScans.used.\(userId)"
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the test command. Expected: 8 `Test Case ... passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add ArchieTests/FreeScanCounterTests.swift Archie/Features/FreeScans/FreeScanCounter.swift
git commit -m "feat: add per-user FreeScanCounter"
```

---

### Task 3: PremiumManager — offering limit and prices

**Files:**
- Modify: `Archie/Integrations/RevenueCat/PremiumManager.swift`

- [ ] **Step 1: Add published properties** below `@Published var purchaseError: String?`:

```swift
    @Published private(set) var freeScanLimit: Int?
    @Published private(set) var monthlyPrice: String?
    @Published private(set) var yearlyPrice: String?
```

- [ ] **Step 2: Add `refreshOffering()`** after `checkEntitlement()`:

```swift
    func refreshOffering() async {
        guard isConfigured else { return }
        do {
            let offering = try await Purchases.shared.offerings().current
            freeScanLimit = offering?.metadata[FreeScanPolicy.remoteLimitMetadataKey] as? Int
            monthlyPrice = offering?.monthly?.storeProduct.localizedPriceString
            yearlyPrice = offering?.annual?.storeProduct.localizedPriceString
        } catch {
            print("[PremiumManager] offerings fetch failed: \(error.localizedDescription)")
        }
    }
```

- [ ] **Step 3: Call it** at the end of the `do` block in both `identify(userId:)` and `checkEntitlement()`:

```swift
            await refreshOffering()
```

- [ ] **Step 4: Build**

```bash
xcodebuild build -project Archie.xcodeproj -scheme Archie -destination 'platform=iOS Simulator,name=iPhone 18 Pro' 2>&1 | grep -E "error:|\*\* BUILD"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Archie/Integrations/RevenueCat/PremiumManager.swift
git commit -m "feat: read free scan limit and prices from RevenueCat offering"
```

---

### Task 4: PaywallView

**Files:**
- Rename: `Archie/Shared/Components/RedeemCodeView.swift` → `Archie/Shared/Components/PaywallView.swift`

- [ ] **Step 1: Rename**

```bash
git mv Archie/Shared/Components/RedeemCodeView.swift Archie/Shared/Components/PaywallView.swift
```

- [ ] **Step 2: Replace the file contents**

```swift
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
```

- [ ] **Step 3: Commit** (the app does not build until Task 6 updates `ScanTab`; commit together with Task 6 if preferred)

```bash
git add Archie/Shared/Components/PaywallView.swift
git commit -m "feat: replace invite-code screen with free-scans paywall"
```

---

### Task 5: Counter ownership and user scoping

**Files:**
- Modify: `Archie/App/AppDependencies.swift`
- Modify: `Archie/App/RootView.swift`

- [ ] **Step 1: AppDependencies** — add below `let premiumManager: PremiumManager`:

```swift
    let freeScanCounter: FreeScanCounter
```

and in `init(userSession:)` after `self.premiumManager.configure()`:

```swift
        self.freeScanCounter = FreeScanCounter(userId: userSession.userId)
```

- [ ] **Step 2: RootView** — in the `.onReceive(dependencies.userSession.isSignedInPublisher)` closure, before `Task {`:

```swift
            dependencies.freeScanCounter.setUser(newValue ? dependencies.userSession.userId : nil)
```

- [ ] **Step 3: Commit** (with Task 6 if the build is still red)

```bash
git add Archie/App/AppDependencies.swift Archie/App/RootView.swift
git commit -m "feat: scope free scan counter to signed-in user"
```

---

### Task 6: ScanTab gating, recording and label; ScanView label

**Files:**
- Modify: `Archie/App/Tabs/ScanTab.swift`
- Modify: `Archie/Features/Scan/Views/ScanView.swift`

- [ ] **Step 1: ScanView** — add a stored property and init parameter (default `nil`, placed after `onGalleryGate`):

```swift
    private let freeScanStatus: String?
```

```swift
        freeScanStatus: String? = nil,
```

```swift
        self.freeScanStatus = freeScanStatus
```

and in `idleLayout`, directly after the `ScanHeroHeaderView(...)` call:

```swift
                    if let freeScanStatus {
                        Text(freeScanStatus)
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.ultraThinMaterial))
                    }
```

- [ ] **Step 2: ScanTab** — replace the whole file body with:

```swift
import SwiftUI

@MainActor
struct ScanTab: View {
    @StateObject private var viewModel: ScanViewModel
    @ObservedObject private var premiumManager: PremiumManager
    @ObservedObject private var freeScans: FreeScanCounter
    @State private var showHistory = false
    @State private var showAccount = false
    @State private var showPaywall = false
    @State private var pendingAction: PendingAction?

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self._premiumManager = ObservedObject(wrappedValue: dependencies.premiumManager)
        self._freeScans = ObservedObject(wrappedValue: dependencies.freeScanCounter)
        let coordinator = ScanAnalysisCoordinator(
            historyService: dependencies.historyService
        )
        _viewModel = StateObject(
            wrappedValue: ScanViewModel(coordinator: coordinator)
        )
    }

    var body: some View {
        NavigationStack {
            ScanView(
                viewModel: viewModel,
                userSession: dependencies.userSession,
                onCaptureGate: { scanGate(.camera) },
                onGalleryGate: { scanGate(.gallery) },
                freeScanStatus: freeScanStatus,
                onShowHistory: {
                    if FreeScanPolicy.gatesHistory, !canScan {
                        pendingAction = .history
                        showPaywall = true
                    } else {
                        showHistory = true
                    }
                },
                onShowAccount: { showAccount = true }
            )
        }
        .sheet(isPresented: $showHistory) {
            HistoryTab(dependencies: dependencies)
        }
        .sheet(isPresented: $showAccount) {
            AccountTab(dependencies: dependencies)
        }
        .sheet(isPresented: $showPaywall, onDismiss: handlePaywallDismiss) {
            PaywallView(
                premiumManager: premiumManager,
                freeScanLimit: freeScans.limit,
                onDismiss: { showPaywall = false }
            )
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            recordScanIfNeeded(for: newPhase)
        }
        .onChange(of: premiumManager.freeScanLimit, initial: true) { _, newLimit in
            guard FreeScanPolicy.usesRemoteLimit else { return }
            freeScans.setLimit(newLimit)
        }
    }

    private var canScan: Bool {
        premiumManager.isPremium || freeScans.hasFreeScans
    }

    private var freeScanStatus: String? {
        guard !premiumManager.isPremium else { return nil }
        guard freeScans.hasFreeScans else { return "No free scans left" }
        return "\(freeScans.remaining) of \(freeScans.limit) free scans left"
    }

    private func scanGate(_ action: PendingAction) -> Bool {
        guard canScan else {
            pendingAction = action
            showPaywall = true
            return false
        }
        return true
    }

    private func recordScanIfNeeded(for phase: ScanPhase) {
        guard !premiumManager.isPremium else { return }
        switch (FreeScanPolicy.countTrigger, phase) {
        case (.successfulResult, .result), (.scanStart, .analyzing):
            freeScans.recordScan()
        default:
            break
        }
    }

    private func handlePaywallDismiss() {
        guard premiumManager.isPremium, let action = pendingAction else {
            pendingAction = nil
            return
        }
        pendingAction = nil
        switch action {
        case .history: showHistory = true
        case .camera, .gallery: break
        }
    }

    private enum PendingAction {
        case history, camera, gallery
    }
}
```

Keep the existing file header comment.

- [ ] **Step 3: Build and run all unit tests**

```bash
xcodebuild test -project Archie.xcodeproj -scheme ArchieTests -destination 'platform=iOS Simulator,name=iPhone 18 Pro' 2>&1 | grep -E "error:|failed|\*\* TEST"
```
Expected: `** TEST SUCCEEDED **` (compare against the pre-change baseline if unrelated tests already fail).

- [ ] **Step 4: Commit**

```bash
git add Archie/App/Tabs/ScanTab.swift Archie/Features/Scan/Views/ScanView.swift
git commit -m "feat: gate scans on free scan allowance, show remaining count"
```

---

### Task 7: Manual verification on device (sandbox account)

- [ ] Delete the app, install a debug build, sign in: label reads "10 of 10 free scans left".
- [ ] Successful scan → "9 of 10". Force a failure (airplane mode) → count unchanged.
- [ ] Account and History open while not premium.
- [ ] Temporarily set `FreeScanPolicy.defaultLimit = 2` (do not commit) or use RevenueCat metadata `free_scan_limit = 2`: after 2 scans, camera and gallery open the paywall; title reads "You've used your 2 free scans"; prices come from StoreKit; Terms/Privacy links open.
- [ ] Sandbox purchase from the paywall → paywall closes, label disappears, camera works.
- [ ] Sign out and in with a different account → that account starts at its own count.

---

### Task 8: Build 43

- [ ] Apply Danny's answers to `FreeScanPolicy` (one constant each) and commit.
- [ ] Bump `CURRENT_PROJECT_VERSION` to 43 (both app target configurations in `project.pbxproj`), commit.
- [ ] Archive and upload with Xcode 27.1 (`/Applications/Xcode 27.1.app`), not the default 27.2 (27B52), which App Store Connect rejects.
