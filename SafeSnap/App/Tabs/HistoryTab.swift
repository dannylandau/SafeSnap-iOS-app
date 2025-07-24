//
//  HistoryTab.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//


import SwiftUI

@MainActor
struct HistoryTab: View {
    let dependencies: AppDependencies

    var body: some View {
        NavigationStack {
            HistoryView(dependencies: dependencies)
        }
    }
}
