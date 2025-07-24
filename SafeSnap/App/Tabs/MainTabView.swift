//
//  MainTabView.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 10/07/2025.
//


import SwiftUI
import Clerk

// 1️⃣ Define an enum for your tabs
enum MainTab {
  case history, scan, account

  var title: String {
    switch self {
    case .history: return "History"
    case .scan: return "Scan"
    case .account: return "Account"
    }
  }
}

@MainActor
struct MainTabView: View {
    
    init(initialTab: MainTab = .scan, dependencies: AppDependencies) {
        self._selectedTab = State(initialValue: initialTab)
        self.dependencies = dependencies
    }
  // 2️⃣ Track the currently selected tab, defaulting to .scan
  @State private var selectedTab: MainTab = .scan
    let dependencies: AppDependencies
        
  var body: some View {
      TabView(selection: $selectedTab) {
        makeTab(.history)
        makeTab(.scan)
        makeTab(.account)
      }
    .accentColor(.green)       // optional: tint color
  }
    
    @ViewBuilder
    private func makeTab(_ tab: MainTab) -> some View {
      switch tab {
      case .history:
        HistoryTab(dependencies: dependencies)
          .tabItem { Label("History", systemImage: "clock") }
          .tag(MainTab.history)

      case .scan:
        ScanTab(dependencies: dependencies)
          .tabItem { Label("Scan", systemImage: "camera") }
          .tag(MainTab.scan)

      case .account:
        AccountTab(dependencies: dependencies)
          .tabItem { Label("Account", systemImage: "person") }
          .tag(MainTab.account)
      }
    }
}

#Preview {
  MainTabView(initialTab: .account, dependencies: AppDependencies(clerk: Clerk.shared))
}
