//
//  ScanStepPhase.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 30/07/2025.
//

import Foundation

enum AnalysisPhase: Equatable {
    static func == (lhs: AnalysisPhase, rhs: AnalysisPhase) -> Bool {
        switch (lhs, rhs) {
            case (.preparing, .preparing):
            return true
            case (.openAI, .openAI):
            return true
            case (.report, .report):
            return true
            case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError as NSError == rhsError as NSError
            default :
            return false
        }
    }
    
    case preparing
    case openAI
    case report
    case failed(Error)
}
