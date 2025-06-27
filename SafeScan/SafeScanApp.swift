//
//  SafeScanApp.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 26/06/2025.
//

import SwiftUI

@main
struct SafeScanApp: App {
    @AppStorage("hasLaunched") private var hasLaunched = false

    var body: some Scene {
        WindowGroup {
            if hasLaunched {
                CameraView()
            } else {
                WelcomeView()
            }
        }
    }
}
