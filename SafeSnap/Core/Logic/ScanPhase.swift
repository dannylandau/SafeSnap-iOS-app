//
//  ScanPhase.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//


enum ScanPhase: String {
    case vision = "Analyzing Image..."
    case fda = "Checking Recalls (FDA)"
    case who = "Verifying Risks (WHO)"
    case scoring = "Finalizing Safety Score"
}