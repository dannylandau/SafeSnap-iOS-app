# Archie App Store Release Preparation

## Context

Archie (com.VariFax.Archie) is a SwiftUI iOS product safety scanning app. Core release blockers — Sign in with Apple, RevenueCat premium gating, and account deletion — are implemented (commit c15ccaf). Uncommitted work refines the premium UX. The app will be published under the current developer team, then transferred to the Signature Labs Apple account post-launch.

## Goal

Finalize the codebase for App Store submission with three clean, logical commits.

## Decisions Made

- **Deployment target**: Lower from iOS 18.5/18.6 to **iOS 17.0** (no code changes needed — no iOS 18-specific APIs are used; iOS 17 floor is set by `.onChange(of:) { _, newValue in }` two-parameter variant)
- **Premium gating UX**: Per-action gating (camera, gallery, history, account each trigger a RedeemCodeView sheet) — users can see the scan screen but are prompted when they try to act
- **Test purchase controls**: Gate to `#if DEBUG` only — TestFlight/production users must never see the orange test purchase buttons or red tester bypass
- **Dead code**: Delete the entire `SafeSnap/` directory (46 files, not referenced by the Xcode project)
- **StoreKit config**: Leave `ArchieStoreKit.storekit` as a loose file, not linked to scheme
- **HistoryView**: Already working correctly with sign-in gate via FirebaseAuthView — no changes needed

## Commit Plan

### Commit 1: `feat: restructure premium gating to per-action prompts with RedeemCodeView`

Stage and commit existing uncommitted changes with no modifications:

| File | Change |
|------|--------|
| `Archie.xcodeproj/project.pbxproj` | Project file updates for new files |
| `Archie/App/Tabs/MainTabView.swift` | Remove inline RedeemCodeView, simplify to always show ScanTab |
| `Archie/App/Tabs/ScanTab.swift` | Add per-action gating logic (capture, gallery, history, account) with RedeemCodeView sheet |
| `Archie/Features/Scan/Views/ScanView.swift` | Add `onCaptureGate` and `onGalleryGate` closure parameters |
| `Archie/Integrations/RevenueCat/PremiumManager.swift` | Add purchase methods (monthly/yearly), UserDefaults caching, sandbox detection |
| `Archie/Shared/Components/RedeemCodeView.swift` | New file — extracted standalone redeem/purchase component |
| `Archie/Resources/ArchieStoreKit.storekit` | New file — StoreKit testing configuration (unlinked) |

### Commit 2: `fix: restrict test controls to DEBUG builds, lower deployment target to iOS 17, remove dead code`

Three changes:

1. **RedeemCodeView.swift**: Replace runtime `if PremiumManager.isSandbox {` guard with compile-time `#if DEBUG` / `#endif` around the test purchase section (Monthly, Yearly, Tester Bypass buttons)
2. **Archie.xcodeproj/project.pbxproj**: Change all `IPHONEOS_DEPLOYMENT_TARGET` values to `17.0`
3. **Delete `SafeSnap/` directory**: 46 dead files not referenced by the Xcode project

### Commit 3: `chore: bump build number for App Store submission`

- **Archie.xcodeproj/project.pbxproj**: Increment `CURRENT_PROJECT_VERSION` from 37 to 38

## Out of Scope

- StoreKit config linking to Xcode scheme
- Any new features or UX changes beyond what's already implemented
- App Store Connect metadata, screenshots, or review notes
- Post-publish transfer to Signature Labs (handled separately after app is live)

## Post-Submission: Transfer to Signature Labs

After the app is approved and live:

1. Initiate app transfer in App Store Connect to Signature Labs
2. Generate new .p8 key from Signature Labs account
3. Update shared secret + .p8 key in RevenueCat dashboard
4. Verify S2S notifications
5. Test a purchase/restore to confirm reconnection

Stripe is unaffected by the transfer.
