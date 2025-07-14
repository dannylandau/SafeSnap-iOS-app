//
//  MainTabView.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 10/07/2025.
//


import SwiftUI

// 1️⃣ Define an enum for your tabs
private enum MainTab {
  case history, scan, account
}

struct MainTabView: View {
  // 2️⃣ Track the currently selected tab, defaulting to .scan
  @State private var selectedTab: MainTab = .scan

  var body: some View {
    TabView(selection: $selectedTab) {
      // 3️⃣ History tab
      HistoryView()
        .tabItem {
          Label("History", systemImage: "clock")
        }
        .tag(MainTab.history)  // ← tag this view as .history

      // 4️⃣ Scan tab (middle) – this will now show first
      HomeView()
        .tabItem {
          Label("Scan", systemImage: "camera")
        }
        .tag(MainTab.scan)     // ← tag this view as .scan

      // 5️⃣ Account tab
      AccountView()
        .tabItem {
          Label("Account", systemImage: "person")
        }
        .tag(MainTab.account)  // ← tag this view as .account
    }
    .accentColor(.green)       // optional: tint color
  }
}
