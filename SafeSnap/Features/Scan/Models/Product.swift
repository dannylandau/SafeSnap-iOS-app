//
//  Product.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//


import Foundation

struct Product: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let productType: String
    let safetyScore: Int
    let safetyLevel: String
    let pros: [SafetyPoint]
    let cons: [SafetyPoint]
    let certifications: [String]
    let hygieneWarnings: [HygieneWarning]
}

struct SafetyPoint: Identifiable, Codable, Hashable {
    let id: String
    let label: String
    let severity: String
    let category: String
}

struct HygieneWarning: Identifiable, Codable, Hashable {
    var id: String { type }
    let type: String
    let message: String
}
