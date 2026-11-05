# Free Scans — Design

Replace the invite-code gate on the first scan with N free scans, so App Review (and new users) see the full app working without a code or purchase. Approved by Danny on 2026-10-25 (~5h estimate).

## Client decisions

Asked Danny on 2026-11-02; on 2026-11-04 he chose the recommended default for all three. Each answer maps to one constant in `FreeScanPolicy`.

| # | Question | Default (recommended) | Alternative | Constant |
|---|----------|----------------------|-------------|----------|
| 1 | When does a scan count? | Only on a successful result | As soon as a scan starts | `FreeScanPolicy.countTrigger` |
| 2 | What is locked after free scans? | Only new scans (camera/gallery) | Scans and History | `FreeScanPolicy.gatesHistory` |
| 3 | Limit adjustable without an app update? | Yes, via RevenueCat offering metadata `free_scan_limit` | Fixed in app | `FreeScanPolicy.usesRemoteLimit` |

Account is never gated, regardless of answer 2: Apple requires account deletion to be reachable in-app.

## Behaviour

- Non-premium users get `limit` free scans (default 10). Premium users (entitlement `premium`) are never counted or gated.
- The scan screen shows "X of N free scans left" for non-premium users; at zero, "No free scans left".
- When `remaining == 0`, tapping camera or gallery opens the paywall instead of scanning.
- Counter is stored on device in `UserDefaults`, keyed per Firebase user ID (`anonymous` when signed out). Reinstalling resets it — accepted for launch.
- Limit: if `usesRemoteLimit`, read integer metadata `free_scan_limit` from RevenueCat's current offering; missing, invalid or not-yet-loaded falls back to `defaultLimit` (10). Fetched on launch and on each entitlement refresh (app becomes active).

## Components

- **`FreeScanPolicy`** (new, `Archie/Features/FreeScans/`): the three decision constants, `defaultLimit`, metadata key, Terms/Privacy URLs. No logic.
- **`FreeScanCounter`** (new, same folder): `@MainActor ObservableObject`. Inputs: `UserDefaults`, current user ID, limit. Exposes `used`, `limit`, `remaining`, `hasFreeScans`, `recordScan()`, `setUser(_:)`, `setLimit(_:)`. Unit-tested.
- **`PremiumManager`** (existing): additionally publishes `freeScanLimit: Int?` (from offering metadata) and `monthlyPrice` / `yearlyPrice` (StoreKit `localizedPriceString`, fallback to the current hardcoded strings).
- **`ScanTab`** (existing): owns the gating. Camera/gallery allowed if `isPremium || counter.hasFreeScans`. History gated only if `gatesHistory`. Account never gated. Records a scan by observing `viewModel.phase`: `.result` for `.successfulResult`, `.analyzing` for `.scanStart`; skipped for premium users.
- **`ScanView`** (existing): new optional `freeScanStatus: String?` shown under the hero header in the idle layout.
- **`PaywallView`** (renamed from `RedeemCodeView`): title "You've used your N free scans", subtitle about subscribing to keep scanning; Monthly / Yearly as primary buttons with StoreKit prices; auto-renew disclosure; Terms of Use and Privacy Policy links; secondary "Have an invite code?" (offer-code sheet); Restore Purchases; DEBUG-only tester bypass kept.
- **`AppDependencies` / `RootView`**: create the counter; on sign-in/out call `counter.setUser`.

## Legal links

- Privacy Policy: `https://archieml.com/privacy`
- Terms of Use: Apple standard EULA `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/` unless Danny supplies his own.
- archieml.com is a single-page app returning 200 for every path, so the privacy page must be checked manually in a browser before submission.

## Error handling

- RevenueCat offerings fail to load → limit stays at default, prices stay at fallback strings; scanning unaffected.
- Purchase errors keep the existing "Purchase Failed" alert.

## Testing

- Unit (`ArchieTests/FreeScanCounterTests.swift`): starts at zero; `recordScan` increments and persists; `remaining` never negative; `hasFreeScans` false at limit; per-user isolation; switching users reloads; `setLimit` changes `remaining`; non-positive limit falls back to default.
- Manual on device (sandbox account): fresh install shows "10 of 10"; successful scan decrements; failed scan does not; at zero camera/gallery open paywall; Account and History reachable while not premium; sandbox purchase unlocks and hides the label; RevenueCat metadata change to 3 reflected after relaunch.

## Out of scope

Server-side counting (reinstall-proof), redesigning the paywall visuals, App Store screenshots.
