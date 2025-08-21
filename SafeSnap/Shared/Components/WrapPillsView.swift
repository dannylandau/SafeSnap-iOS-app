//
//  WrapPillsView.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//


import SwiftUI

struct WrapPillsView: View {
    let pills: [(emoji: String, label: String)]
    let columns = [GridItem(.adaptive(minimum: 150, maximum: 260), spacing: 12, alignment: .center)]

    @State private var appear = false

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 8) {
            ForEach(Array(pills.enumerated()), id: \.1.label) { index, pill in
                Text(pill.emoji + " " + pill.label)
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color(.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .clipShape(Capsule())
                    .opacity(appear ? 1 : 0)
                    .scaleEffect(appear ? 1 : 0.9)
                    .animation(.easeOut.delay(Double(index) * 0.05), value: appear)
            }
        }
        .padding(.horizontal)
        .onAppear {
            appear = true
        }
    }
}

// TODO: Replace emojis with sfsymbols?

/// A simple wrapper for your emoji+title pills
struct PillData {
    /// The seven default categories
    static let `default` = [
        ("📦","All"),
        ("🍎","Food"),
        ("💄","Cosmetic"),
        ("🧸","Toy"),
        ("💻","Electronic"),
        ("🏠","Household"),
        ("👕","Clothing"),
        ("🐶","Animal"),
        ("💍","Jewelry"),
        ("💊","Pharmaceutical"),
        ("🚗","Automotive"),
        ("❓","Other")
    ]
}
