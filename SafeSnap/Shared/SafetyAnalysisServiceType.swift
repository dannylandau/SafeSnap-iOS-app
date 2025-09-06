//
//  GeminiServiceType.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 06/09/2025.
//

import SwiftUI

public protocol SafetyAnalysisServiceType {
    /// Start a full image->JSON safety analysis.
    func analyzeSafety(
        image: UIImage,
        options: SafetyOptions,
        streamToken: ((String) -> Void)?
    ) async throws -> SafetyAnalysisResponse

    /// Cancel an in-flight call, if any.
    func cancelAnalysis()
}
