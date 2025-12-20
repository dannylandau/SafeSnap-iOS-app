//
//  ImageAnalysisService.swift
//  Archie
//
//  Created by Marcin Grześkowiak on 23/07/2025.
//


import UIKit

protocol ImageAnalysisService {
    func analyze(image: UIImage) async -> AnalysisResult
}

struct AnalysisResult {
    let resultVM: RecognitionResultViewModel
    let historyItem: ScanHistoryItem
}
