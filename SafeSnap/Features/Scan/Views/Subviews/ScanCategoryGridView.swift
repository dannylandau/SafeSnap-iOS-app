//
//  ScanCategoryGridView.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 02/08/2025.
//

import SwiftUI

struct ScanCategoryGridView: View {
    let categories: [ScanCategory]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 12) {
            ForEach(categories) { category in
                VStack(spacing: 6) {
                    Image(category.iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(category.tint)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Text(category.title)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
            }
        }
    }
}

#if DEBUG
struct ScanCategoryGridView_Previews: PreviewProvider {
    static var previews: some View {
        ScanCategoryGridView(categories: ScanCategory.homeDefaults)
            .padding()
            .background(Color(uiColor: .systemGray6))
    }
}
#endif
