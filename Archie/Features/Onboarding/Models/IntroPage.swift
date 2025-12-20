//
//  IntroPage.swift
//  Archie
//
//  Created by Marcin Grześkowiak on 02/08/2025.
//

import SwiftUI

struct IntroPage: Identifiable, Equatable {
    enum Accent: String {
        case kids
        case pets
        case reports

        var color: Color {
            switch self {
            case .kids: return Color(red: 0.41, green: 0.64, blue: 0.99)
            case .pets: return Color(red: 0.14, green: 0.74, blue: 0.45)
            case .reports: return Color(red: 0.10, green: 0.71, blue: 0.44)
            }
        }
    }

    let id = UUID()
    let illustrationName: String
    let title: String
    let subtitle: String
    let accent: Accent
    let ctaTitle: String?

    static let mockPages: [IntroPage] = [
        IntroPage(
            illustrationName: "IntroKidsSafety",
            title: "Kids Safety Matter",
            subtitle: "Want to check safety analysis that most matter for your kid?",
            accent: .kids,
            ctaTitle: nil
        ),
        IntroPage(
            illustrationName: "IntroPetSafety",
            title: "Your Pets Safety",
            subtitle: "Recognise things that are good or not for your pet's safety.",
            accent: .pets,
            ctaTitle: nil
        ),
        IntroPage(
            illustrationName: "IntroSafetyReport",
            title: "Get Safety Report",
            subtitle: "Get AI powered safety report of products for your kids.",
            accent: .reports,
            ctaTitle: "Continue with Google"
        )
    ]
}
