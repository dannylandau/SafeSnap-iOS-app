//
//  SourceService.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//


import Foundation

class SourceService {
    static let shared = SourceService()

    private var sources: [String: [String]] = [:]

    private init() {
        load()
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "productSources", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            print("⚠️ Failed to load productSources.json")
            return
        }

        sources = decoded
    }

    func sources(for category: String) -> [String] {
        sources[category.lowercased()] ?? []
    }
}
