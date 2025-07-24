# 📱 SafeSnap

**AI-powered product safety scanner.**  
Analyze product labels and packaging using Vision AI + OpenAI, check safety databases, and store scan history across sessions.

---

![Build](https://img.shields.io/github/actions/workflow/status/yourusername/safesnap/ci.yml)
![License](https://img.shields.io/github/license/yourusername/safesnap)
![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-blue)

---

## 🚀 Features

- 📸 **Scan via camera or photos**
- 🧠 **Google Vision + OpenAI analysis**
- 📊 **Safety score and risk breakdown**
- 🐾 **Pet- and kid-specific warnings**
- 🗂️ **Persistent scan history**
- 🧑‍💼 **Account integration with Clerk**
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
- GitHub account with [Clerk](https://clerk.dev) API keys

---

## 🔧 Setup

```bash
git clone https://github.com/yourusername/safesnap.git
cd safesnap
open SafeSnap.xcodeproj
```

Make sure to set `ClerkPublishableKey` in your `Info.plist`:

```xml
<key>ClerkPublishableKey</key>
<string>REDACTED</string>
```

---

## 🧰 Tech Stack

| Layer       | Tooling                              |
|-------------|---------------------------------------|
| UI          | SwiftUI, NavigationStack              |
| State       | @StateObject, Combine, @MainActor     |
| Auth        | Clerk.dev                             |
| AI          | Google Vision API + OpenAI            |
| Storage     | Codable + JSON file per user          |
| Testing     | XCTest, async/await, Mocks            |

---

## 👥 Contributors

- [@marcingie](https://github.com/marcingie)

---

## 📜 License

MIT © 2025 SafeSnap
