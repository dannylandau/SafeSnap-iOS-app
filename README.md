# 📱 SafeSnap

**AI-powered product safety scanner.**  
Analyze product labels and packaging using Vision AI + OpenAI, check safety databases, and store scan history across sessions.

---

![Build](https://github.com/dannylandau/SafeSnap-iOS-app/actions/workflows/unit_tests.yml/badge.svg)
![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-blue)

---

## 🚀 Features

- 📸 **Scan via camera or photos**
- 🧠 **Google Vision + OpenAI analysis**
- 📊 **Safety score and risk breakdown**
- 🐾 **Pet- and kid-specific warnings**
- 🗂️ **Persistent scan history**
- 🧑‍💼 **Google sign-in via Firebase Auth**
- 📈 **Personal safety stats**
- 🛠️ **Built with SwiftUI and Combine**

---

## 🧱 Architecture

- **SwiftUI** for declarative UI
- **MVVM + Coordinators** for feature structure
- **@MainActor + structured concurrency** for thread safety
- **Dependency injection** via `AppDependencies`
- **Testable services** with protocol abstractions and mockable components

---

## 🧪 Tests

- ✅ Unit tests for all major view models and services
- 🧪 End-to-end flow tests for scan + result + stats
- 🧼 Isolated mocks and temp file injection for persistence logic

Run tests in Xcode:

```bash
⌘ + U
```

---

## 📷 Screenshots

| Scan Flow | Result View | Account Stats |
|-----------|-------------|----------------|
| ![](./assets/scan.png) | ![](./assets/result.png) | ![](./assets/account.png) |

---

## 📦 Requirements

- iOS 17+
- Swift 5.9+
- Xcode 15.0+
- Firebase project with a configured iOS app

---

## 🔧 Setup

```bash
git clone https://github.com/yourusername/safesnap.git
cd safesnap
open SafeSnap.xcodeproj
```

Replace the placeholder values inside `SafeSnap/Resources/GoogleService-Info.plist` with the file downloaded from the Firebase console (or copy your real file over that path). Update `SafeScan-Info.plist` with your reversed client ID under `CFBundleURLTypes` so Google authentication can hand control back to the app. The app will crash on launch if the configuration is missing or still contains the `REPLACE_WITH_…` placeholders so misconfiguration surfaces immediately during QA.

---

## 🧰 Tech Stack

| Layer       | Tooling                              |
|-------------|---------------------------------------|
| UI          | SwiftUI, NavigationStack              |
| State       | @StateObject, Combine, @MainActor     |
| Auth        | Firebase Authentication                |
| AI          | Google Vision API + OpenAI            |
| Storage     | Codable + JSON file per user          |
| Testing     | XCTest, async/await, Mocks            |

---

## 👥 Contributors

- [@marcingie](https://github.com/marcingie)

