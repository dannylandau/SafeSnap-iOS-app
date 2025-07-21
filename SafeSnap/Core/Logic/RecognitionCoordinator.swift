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
            var labels: [String] = []
            
            onPhaseChange(.vision)
            let visionGroup = DispatchGroup()
            visionGroup.enter()
            VisionService.recognizeLabels(from: image) { result in
                labels = result
                visionGroup.leave()
            }
            visionGroup.wait()
            
            
            
            guard let product = labels.compactMap({ SafetyAnalyzer.shared.analyze(productName: $0)}).first else {
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
