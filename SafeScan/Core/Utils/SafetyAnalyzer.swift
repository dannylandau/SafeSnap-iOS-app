//
//  SafetyAnalyzer.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//


import Foundation

class SafetyAnalyzer {
    static let shared = SafetyAnalyzer()
    
    private var database: [String: Product] = [:]
    
    private init() {
        loadDatabase()
    }
    
    private func loadDatabase() {
        guard let url = Bundle.main.url(forResource: "safetyDatabase", withExtension: "json") else {
            print("❌ Could not find safetyDatabase.json")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let raw = try JSONDecoder().decode([String: Product].self, from: data)
            database = raw
            print("✅ Safety database loaded with \(database.count) entries.")
        } catch {
            print("❌ Failed to decode safetyDatabase.json: \(error)")
        }
    }
    
    func analyze(productName: String) -> Product? {
        let key = productName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return database[key]
    }
}