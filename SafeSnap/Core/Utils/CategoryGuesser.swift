//
//  CategoryGuesser.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//


import Foundation

class CategoryGuesser {
    static let labelToCategory: [String: String] = [
        // Food
        "apple": "food", "banana": "food", "broccoli": "food", "fruit": "food", "vegetable": "food",
        // Toys
        "toy": "toy", "teddy bear": "toy", "lego": "toy", "doll": "toy", "game": "toy",
        // Cosmetics
        "lipstick": "cosmetic", "makeup": "cosmetic", "shampoo": "cosmetic",
        // Electronics
        "phone": "electronic", "laptop": "electronic", "charger": "electronic",
        // Household
        "cleaner": "household", "detergent": "household", "bleach": "household"
    ]

    static func guessCategory(from labels: [String]) -> String? {
        for label in labels {
            if let category = labelToCategory[label.lowercased()] {
                return category
            }
        }
        return nil
    }
}