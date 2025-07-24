//
//  FilterPillsView.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 21/07/2025.
//


import SwiftUI

/// A pills-style grid where you can tap to select one item at a time.
struct FilterPillsView: View {
    /// The full set of (emoji, label) tuples.
    let pills: [(emoji: String, label: String)]
    /// Currently selected label. Bind this to your parent.
    @Binding var selected: String

    /// Layout: adaptively sized capsules
    private let columns = [
        GridItem(.adaptive(minimum: 80), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(pills, id: \.label) { pill in
                let isSelected = (pill.label == selected)
                Text("\(pill.emoji) \(pill.label)")
                    .font(.subheadline)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.green : Color(.secondarySystemBackground))
                    )
                    .foregroundColor(isSelected ? .white : .primary)
                    .onTapGesture {
                        selected = pill.label
                    }
            }
        }
    }
}

// MARK: — Preview

struct FilterPillsView_Previews: PreviewProvider {
    struct Wrapper: View {
        @State private var selected = "Food"
        let sample = [
            ("📦","All"),
            ("🍎","Food"),
            ("🧸","Toys"),
            ("💄","Beauty"),
            ("💻","Tech"),
            ("🏠","Home")
        ]

        var body: some View {
            VStack(spacing: 20) {
                Text("Selected: \(selected)")
                FilterPillsView(pills: sample, selected: $selected)
            }
            .padding()
        }
    }

    static var previews: some View {
        Wrapper()
            .previewLayout(.sizeThatFits)
    }
}
