//
//  Product.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//


import Foundation

struct Product: Decodable {
    let name: String
    let safetyScore: Int
    let safetyLevel: String
    let pros: [SafetyPoint]
    let cons: [SafetyPoint]
    let certifications: [String]
}

struct SafetyPoint: Decodable, Identifiable {
    let id: String
    let label: String
    let severity: String
    let category: String
}
