//
//  ScanStepPhase.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 30/07/2025.
//

enum AnalysisPhase {
    case preparing
    case openAI
    case report
    case failed(Error)
}
