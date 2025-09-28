//
//  RootView.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//

import SwiftUI

struct RootView: View {
    let dependencies: AppDependencies
    
    var body: some View {
        MainTabView(dependencies: dependencies)
    }
}
