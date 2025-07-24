//
//  Color+Extensions.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 14/07/2025.
//

import SwiftUI

extension Color {
    /// Light/dark–mode–aware system background
    static var systemBackground: Color {
        Color(UIColor.systemBackground)
    }

    /// The grouped secondary background used in cards & lists
    static var secondarySystemBackground: Color {
        Color(UIColor.secondarySystemBackground)
    }

    /// A subtle blue info background that adapts to dark/light
    static var infoBackground: Color {
        Color(UIColor { trait in
            let base = UIColor.systemBlue
            return trait.userInterfaceStyle == .dark
                ? base.withAlphaComponent(0.2)
                : base.withAlphaComponent(0.1)
        })
    }
}
