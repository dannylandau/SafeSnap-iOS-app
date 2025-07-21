//
//  HeaderView.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 14/07/2025.
//

import SwiftUI

struct HeaderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image("AppIconGradientCircle")
                .resizable().frame(width: 80, height: 80)
            Text("SafeSnap").font(.largeTitle.bold())
            Text("AI-powered product safety analysis")
                .font(.subheadline).foregroundColor(.secondary)
        }
        .padding(.top, 16)
    }
}
