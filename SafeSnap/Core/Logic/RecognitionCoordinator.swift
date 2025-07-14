//
//  RecognitionCoordinator.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//


import UIKit

class RecognitionCoordinator {
    static func analyze(image: UIImage, onPhaseChange: @escaping (ScanPhase) -> Void, completion: @escaping (RecognitionResult?) -> Void) {
        DispatchQueue.global().async {
            var labels: [String] = []

            onPhaseChange(.vision)
            let visionGroup = DispatchGroup()

            visionGroup.enter()
            VisionService.recognizeLabels(from: image) { result in
                labels = result
                visionGroup.leave()
            }

            visionGroup.wait()

            onPhaseChange(.fda)
            Thread.sleep(forTimeInterval: 1.2)

            onPhaseChange(.who)
            Thread.sleep(forTimeInterval: 1.0)

            onPhaseChange(.scoring)
            Thread.sleep(forTimeInterval: 0.5)

            let category = CategoryGuesser.guessCategory(from: labels)
            let product = labels
                .compactMap { SafetyAnalyzer.shared.analyze(productName: $0) }
                .first

            DispatchQueue.main.async {
                completion(RecognitionResult(product: product, category: category, labels: labels))
            }
        }
    }
}
