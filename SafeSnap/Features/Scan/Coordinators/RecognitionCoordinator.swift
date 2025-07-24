//
//  RecognitionCoordinator.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//


import UIKit

class RecognitionCoordinator {
    static func analyze(
        image: UIImage,
        onPhaseChange: @escaping (ScanPhase) -> Void,
        completion: @escaping (RecognitionResult?) -> Void
    ) {
        Task.detached(priority: .userInitiated) {
            onPhaseChange(.vision)
            let labels = await withCheckedContinuation { continuation in
                VisionService.recognizeLabels(from: image) { result in
                    continuation.resume(returning: result)
                }
            }
            
            guard let product = labels.compactMap({ SafetyAnalyzer.shared.analyze(productName: $0) }).first else {
                return completion(nil)
            }
            
            await MainActor.run {
                completion(
                    RecognitionResult(
                        product: product,
                        labels: labels,
                        score: 90.0
                    )
                )
            }
        }
    }
}
