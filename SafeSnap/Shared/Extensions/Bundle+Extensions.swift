//
//  Bundle+Extensions.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 30/07/2025.
//

import Foundation

extension Bundle {
    func infoDictionaryValue(for key: String) -> String? {
        guard let path = path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) else { return nil }
        return dict[key] as? String
    }
}
