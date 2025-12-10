# Archie Share Flow Specification

This document explains how the **share** feature works in the Archie web app, and how other clients (e.g. iOS) should integrate with it.

---

## 1. Overview

Archie allows users to share a scan result (kid/pet safety analysis) via a **public share URL**. The architecture is simple:

- Each analysis has a unique **`analysis.id`**.
- The share URL is derived from this id:
  - `https://<web-origin>/share/{analysisId}`
- The `/share/[id]` web route (and the backend) know how to load and render the corresponding analysis for that id.

Other clients (e.g. iOS) should **reuse this exact URL format** so that all platforms share the same links.

---

## 2. Current Web Implementation

Location (Next.js): `src/app/result/[id]/page.tsx`

Relevant snippet:

```tsx
const text = `Archie result for ${analysis.name}: ${analysis.safetyScore.overall}/${analysis.safetyScore.maxScore}`;
const url = `${window.location.origin}/share/${analysis.id}`;

if (navigator.share) {
  navigator.share({ title: "Archie Result", text, url }).catch(() => {});
} else {
  navigator.clipboard?.writeText(text + " " + url).catch(() => {});
  showToast("Result copied to clipboard", "success");
}
```

### Behaviour

- **`analysis.id`**

  - A stable identifier for an analysis record.
  - Example: `green-grapes-17651684409663`.

- **Share URL**

  - Pattern: `https://archieml.com/share/{analysisId}`
  - Example: `https://archieml.com/share/green-grapes-17651684409663`

- **Share text**
  - Example: `Archie result for Green Grapes: 4.3/10`

If the browser supports the Web Share API, the web app opens the native share sheet.
Otherwise it falls back to copying the `{text} {url}` string to the clipboard.

The `/share/[id]` route loads the analysis by id and renders the same detail view.

---

## 3. iOS Integration Guide

The iOS client should:

1. **Store the same `analysis.id`** that the backend returns for a scan.
2. Build the same share URL as the web client.
3. Use the native share sheet (`UIActivityViewController`) to share the URL and a short description.

### 3.1. Required data

From the analysis model on iOS, you need at minimum:

- `id: String` – analysis id
- `name: String` – display name (e.g. `Green Grapes`)
- `safetyScore.overall: Int | Double`
- `safetyScore.maxScore: Int` (usually `10`)

### 3.2. Building the URL and text (Swift)

```swift
let analysisId: String = result.id
let baseURL = URL(string: "https://archieml.com")! // production web origin
let shareURL = baseURL
    .appendingPathComponent("share")
    .appendingPathComponent(analysisId)

let scoreText = "\(result.safetyScore.overall)/\(result.safetyScore.maxScore)"
let shareText = "Archie result for \(result.name): \(scoreText)"
```

### 3.3. Presenting the native share sheet (UIKit)

```swift
import UIKit

func shareArchieResult(from viewController: UIViewController, result: AnalysisResult) {
    let baseURL = URL(string: "https://archieml.com")!
    let shareURL = baseURL
        .appendingPathComponent("share")
        .appendingPathComponent(result.id)

    let scoreText = "\(result.safetyScore.overall)/\(result.safetyScore.maxScore)"
    let shareText = "Archie result for \(result.name): \(scoreText)"

    let activityVC = UIActivityViewController(
        activityItems: [shareText, shareURL],
        applicationActivities: nil
    )

    // iPad safety – required to avoid crashes on iPad
    if let popover = activityVC.popoverPresentationController {
        popover.sourceView = viewController.view
        popover.sourceRect = CGRect(
            x: viewController.view.bounds.midX,
            y: viewController.view.bounds.midY,
            width: 0,
            height: 0
        )
        popover.permittedArrowDirections = []
    }

    viewController.present(activityVC, animated: true)
}
```

> `AnalysisResult` here is the iOS model of an analysis. It only needs `id`, `name`, and `safetyScore` fields to implement sharing.

---

## 4. Optional: Universal Links / Deep Links

If desired, the same share URL can also open **directly in the iOS app** via Universal Links.

### 4.1. URL design

- Keep using: `https://archieml.com/share/{analysisId}`
- Behaviour:
  - **If the app is installed** and Universal Links are configured → open the app and navigate to the result screen.
  - **If the app is not installed** → open the web share page in the browser.

### 4.2. iOS setup (high‑level)

1. Add `applinks:archieml.com` to the app's Associated Domains.
2. Serve an `apple-app-site-association` file from `https://archieml.com/.well-known/apple-app-site-association` describing the `/share/*` path.
3. In the app, handle incoming Universal Links:
   - Parse the path `/share/{analysisId}`.
   - Extract `{analysisId}`.
   - Fetch the analysis via Archie API and navigate to the result detail screen.

No backend changes are required for this; only iOS and the web host configuration.

---

## 5. Summary

- **Canonical share URL**: `https://archieml.com/share/{analysisId}`.
- Web and iOS should **both** generate this URL using the same `analysis.id`.
- Web uses the Web Share API or clipboard; iOS uses `UIActivityViewController`.
- Optional: configure Universal Links so the same URL can deep-link into the iOS app.
