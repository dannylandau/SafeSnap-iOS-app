//
//  ScanCategory.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 02/08/2025.
//

import SwiftUI

struct ScanCategory: Identifiable, Hashable {
    let id = UUID()
    let iconName: String
    let title: String
    let tint: Color

    static let homeDefaults: [ScanCategory] = [
        ScanCategory(iconName: "animals", title: "Animals", tint: Color(red: 0.54, green: 0.76, blue: 0.49)),
        ScanCategory(iconName: "toys", title: "Toys", tint: Color(red: 0.70, green: 0.55, blue: 0.84)),
        ScanCategory(iconName: "jewelry", title: "Jewelry", tint: Color(red: 0.89, green: 0.73, blue: 0.50)),
        ScanCategory(iconName: "beauty", title: "Beauty", tint: Color(red: 0.97, green: 0.62, blue: 0.69)),
        ScanCategory(iconName: "food", title: "Food", tint: Color(red: 0.42, green: 0.77, blue: 0.45)),
        ScanCategory(iconName: "electronics", title: "Electronics", tint: Color(red: 0.43, green: 0.69, blue: 0.89)),
        ScanCategory(iconName: "household", title: "Household", tint: Color(red: 0.61, green: 0.76, blue: 0.90)),
        ScanCategory(iconName: "stationery", title: "Stationery", tint: Color(red: 0.88, green: 0.66, blue: 0.76))
    ]
}
