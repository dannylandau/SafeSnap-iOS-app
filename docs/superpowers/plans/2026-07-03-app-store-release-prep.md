# App Store Release Preparation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finalize the Archie iOS app for App Store submission with three clean commits — staging existing UX work, applying fixes + cleanup, and bumping the build number.

**Architecture:** No new architecture. Three commits that stage existing work, apply targeted fixes (DEBUG gate, deployment target, dead code removal), and bump the build number.

**Tech Stack:** SwiftUI, Xcode project (pbxproj), RevenueCat

---

### Task 1: Stage and commit the premium gating restructure

All changes already exist in the working tree. This task stages and commits them without modification.

**Files:**
- Stage modified: `Archie.xcodeproj/project.pbxproj`
- Stage modified: `Archie/App/Tabs/MainTabView.swift`
- Stage modified: `Archie/App/Tabs/ScanTab.swift`
- Stage modified: `Archie/Features/Scan/Views/ScanView.swift`
- Stage modified: `Archie/Integrations/RevenueCat/PremiumManager.swift`
- Stage new: `Archie/Shared/Components/RedeemCodeView.swift`
- Stage new: `Archie/Resources/ArchieStoreKit.storekit`

- [ ] **Step 1: Stage all modified and new files**

```bash
git add \
  Archie.xcodeproj/project.pbxproj \
  Archie/App/Tabs/MainTabView.swift \
  Archie/App/Tabs/ScanTab.swift \
  Archie/Features/Scan/Views/ScanView.swift \
  Archie/Integrations/RevenueCat/PremiumManager.swift \
  Archie/Shared/Components/RedeemCodeView.swift \
  Archie/Resources/ArchieStoreKit.storekit
```

- [ ] **Step 2: Verify staged changes match expectations**

```bash
git diff --cached --stat
```

Expected output — 7 files staged:
```
Archie.xcodeproj/project.pbxproj                   | 26 ++++-----
Archie/App/Tabs/MainTabView.swift                  | 63 +-----
Archie/App/Tabs/ScanTab.swift                      | 60 +++++++-
Archie/Features/Scan/Views/ScanView.swift          |  8 +++
Archie/Integrations/RevenueCat/PremiumManager.swift| 45 +++++++-
Archie/Resources/ArchieStoreKit.storekit           | (new file)
Archie/Shared/Components/RedeemCodeView.swift      | (new file)
```

- [ ] **Step 3: Commit**

```bash
git commit -m "feat: restructure premium gating to per-action prompts with RedeemCodeView"
```

---

### Task 2: Gate test purchase controls to DEBUG builds

Replace the runtime `PremiumManager.isSandbox` check with a compile-time `#if DEBUG` guard so TestFlight and production users never see the test purchase buttons.

**Files:**
- Modify: `Archie/Shared/Components/RedeemCodeView.swift:39-92`

- [ ] **Step 1: Replace the sandbox guard with #if DEBUG**

In `Archie/Shared/Components/RedeemCodeView.swift`, replace the runtime check on line 39:

```swift
// BEFORE (line 39):
            if PremiumManager.isSandbox {

// AFTER:
            #if DEBUG
```

And replace the closing brace of that `if` block on line 92:

```swift
// BEFORE (line 92):
            }

// AFTER:
            #endif
```

The block between lines 39-92 stays exactly the same — only the guard and its closing delimiter change.

- [ ] **Step 2: Verify the file compiles**

```bash
xcodebuild -project Archie.xcodeproj -scheme Archie -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Stage the change**

```bash
git add Archie/Shared/Components/RedeemCodeView.swift
```

---

### Task 3: Lower deployment target to iOS 17.0

Change all `IPHONEOS_DEPLOYMENT_TARGET` values in the Xcode project from 18.5/18.6 to 17.0.

**Files:**
- Modify: `Archie.xcodeproj/project.pbxproj` (lines 375, 434, 467, 508, 535, 554)

- [ ] **Step 1: Replace all deployment target values**

```bash
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = 18\.[0-9];/IPHONEOS_DEPLOYMENT_TARGET = 17.0;/g' Archie.xcodeproj/project.pbxproj
```

- [ ] **Step 2: Verify all values are now 17.0**

```bash
grep "IPHONEOS_DEPLOYMENT_TARGET" Archie.xcodeproj/project.pbxproj
```

Expected: all 6 lines show `17.0`, no remaining `18.x` values.

- [ ] **Step 3: Verify the project still builds**

```bash
xcodebuild -project Archie.xcodeproj -scheme Archie -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Stage the change**

```bash
git add Archie.xcodeproj/project.pbxproj
```

---

### Task 4: Delete dead SafeSnap directory

Remove the entire `SafeSnap/` directory — 46 files of dead code not referenced by the Xcode project.

**Files:**
- Delete: `SafeSnap/` (entire directory)

- [ ] **Step 1: Verify SafeSnap/ is not referenced by the Xcode project**

```bash
grep -c "SafeSnap/" Archie.xcodeproj/project.pbxproj
```

Expected: `0`

- [ ] **Step 2: Delete the directory**

```bash
rm -rf SafeSnap/
```

- [ ] **Step 3: Stage the deletion**

```bash
git add -A SafeSnap/
```

- [ ] **Step 4: Verify staged deletions**

```bash
git diff --cached --stat -- SafeSnap/ | tail -3
```

Expected: ~46 files deleted.

---

### Task 5: Commit all fixes and cleanup together

Combines Tasks 2, 3, and 4 into a single commit.

- [ ] **Step 1: Verify all three changes are staged**

```bash
git diff --cached --stat
```

Expected: `RedeemCodeView.swift` modified, `project.pbxproj` modified, ~46 `SafeSnap/` files deleted.

- [ ] **Step 2: Commit**

```bash
git commit -m "fix: restrict test controls to DEBUG builds, lower deployment target to iOS 17, remove dead code"
```

---

### Task 6: Bump build number for App Store submission

Increment `CURRENT_PROJECT_VERSION` for the main Archie target from 37 to 38.

**Files:**
- Modify: `Archie.xcodeproj/project.pbxproj` (lines 454, 495)

- [ ] **Step 1: Bump the Archie target build number from 37 to 38**

Only replace the two instances for the main target (build 37). Do not touch the test targets (build 1).

```bash
sed -i '' 's/CURRENT_PROJECT_VERSION = 37;/CURRENT_PROJECT_VERSION = 38;/g' Archie.xcodeproj/project.pbxproj
```

- [ ] **Step 2: Verify the change**

```bash
grep "CURRENT_PROJECT_VERSION" Archie.xcodeproj/project.pbxproj
```

Expected:
```
CURRENT_PROJECT_VERSION = 38;  (×2, Archie target Debug + Release)
CURRENT_PROJECT_VERSION = 1;   (×4, test targets unchanged)
```

- [ ] **Step 3: Stage and commit**

```bash
git add Archie.xcodeproj/project.pbxproj
git commit -m "chore: bump build number to 38 for App Store submission"
```

---

### Task 7: Final verification

- [ ] **Step 1: Verify clean working tree**

```bash
git status
```

Expected: `nothing to commit, working tree clean` (apart from untracked files not part of this work).

- [ ] **Step 2: Verify commit history**

```bash
git log --oneline -4
```

Expected three new commits on top:
```
<hash> chore: bump build number to 38 for App Store submission
<hash> fix: restrict test controls to DEBUG builds, lower deployment target to iOS 17, remove dead code
<hash> feat: restructure premium gating to per-action prompts with RedeemCodeView
<hash> docs: add App Store release preparation spec
```

- [ ] **Step 3: Final build check**

```bash
xcodebuild -project Archie.xcodeproj -scheme Archie -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`
