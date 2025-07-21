//
//  Array+Extensions.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 21/07/2025.
//

// MARK: — Array Average Extension
extension Array where Element == Int {
    func average() -> Double {
        guard !isEmpty else { return 0 }
        return Double(reduce(0, +)) / Double(count)
    }
}
