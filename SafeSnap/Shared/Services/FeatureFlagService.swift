//
//  FeatureFlagService.swift
//  SafeSnap
//
//  Created by Coding Assistant on 2025-08-08.
//

import Foundation

enum FeatureFlag: String, CaseIterable {
    case scanDurationTimer

    var defaultsKey: String { "featureFlag.\(rawValue)" }
    var infoPlistKey: String { "FeatureFlag_\(rawValue)" }

    var defaultValue: Bool {
        switch self {
        case .scanDurationTimer:
            return false
        }
    }
}

protocol FeatureFlagProviding {
    func isEnabled(_ flag: FeatureFlag) -> Bool
    func setEnabled(_ flag: FeatureFlag, value: Bool)
    func clearOverride(_ flag: FeatureFlag)
}

final class FeatureFlagService: FeatureFlagProviding {
    static let shared = FeatureFlagService()

    private let defaults: UserDefaults
    private let bundle: Bundle

    init(defaults: UserDefaults = .standard, bundle: Bundle = .main) {
        self.defaults = defaults
        self.bundle = bundle
    }

    func isEnabled(_ flag: FeatureFlag) -> Bool {
        if defaults.object(forKey: flag.defaultsKey) != nil {
            return defaults.bool(forKey: flag.defaultsKey)
        }
        if let value = bundle.object(forInfoDictionaryKey: flag.infoPlistKey) as? Bool {
            return value
        }
        return flag.defaultValue
    }

    func setEnabled(_ flag: FeatureFlag, value: Bool) {
        defaults.set(value, forKey: flag.defaultsKey)
    }

    func clearOverride(_ flag: FeatureFlag) {
        defaults.removeObject(forKey: flag.defaultsKey)
    }
}
