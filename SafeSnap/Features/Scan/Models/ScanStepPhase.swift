//
//  ScanStepPhase.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 30/07/2025.
//


enum ScanStepPhase: CaseIterable, Equatable {
    case preparing
    case vision
    case detecting
    case openAI
    case identify
    case databases
    case openAISafety
    case petSafety
    case report

    var text: String {
        switch self {
        case .preparing: return "Preparing image for analysis..."
        case .vision: return "🔍 Connecting to Google Vision API..."
        case .detecting: return "🎯 Detecting objects and labels..."
        case .openAI: return "🤖 Running OpenAI Vision analysis..."
        case .identify: return "🎯 Identifying specific product details..."
        case .databases: return "🛡️ Checking safety databases (FDA, CPSC, EPA)..."
        case .openAISafety: return "🤖 Running OpenAI safety analysis..."
        case .petSafety: return "🐕🐈 Analyzing pet safety implications..."
        case .report: return "📝 Generating comprehensive safety report..."
        }
    }
}