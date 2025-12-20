//
//  AccountTab.swift
//  Archie
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//

import SwiftUI

@MainActor
struct AccountTab: View {
    let dependencies: AppDependencies

    var body: some View {
        NavigationStack {
            AccountView(dependencies: dependencies)
        }
    }
}
