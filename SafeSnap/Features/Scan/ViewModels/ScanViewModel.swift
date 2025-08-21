//
//  ScanViewModel.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 22/07/2025.
//

import Foundation
import PhotosUI
import SwiftUI

final class ScanViewModel: ObservableObject {
    
    @Published var resultVM: RecognitionResultViewModel? = nil
    @Published var scanStep: ScanStepPhase = .preparing
    
    @Published var phase: ScanPhase = .idle

    @Published var scanError: ScanError? = nil

    private var lastImageData: Data?
    private var lastUIImage: UIImage?
    private var lastIncludeDog: Bool = false
    private var lastIncludeCat: Bool = false
    private var lastIncludeChildren: Bool = false

    let coordinator: ScanAnalysisCoordinator

    init(coordinator: ScanAnalysisCoordinator) {
        self.coordinator = coordinator
    }

    func handleImage(_ image: UIImage) {
        Task { @MainActor in
            self.scanStep = .preparing
            self.resultVM = nil
            self.phase = .analyzing(image: image)
        }
    }

    func beginScan(with imageData: Data, uiImage: UIImage, includeDog: Bool, includeCat: Bool, includeChildren: Bool) {
        self.handleImage(uiImage)
        lastImageData = imageData
        lastUIImage = uiImage
        let thumbnail = uiImage.resizedThumbnail()

        Task {
            do {
                try await coordinator.start(with: imageData, thumbnail: thumbnail, includeDog: includeDog, includeCat: includeCat, includeChildren: includeChildren)
                if let result = await coordinator.latestHistoryItem {
                    let viewModel = RecognitionResultViewModel(image: uiImage, from: result)
                    await MainActor.run {
                        self.resultVM = viewModel
                        self.phase = .result(viewModel)
                    }
                }
            } catch let error as ScanError {
                await MainActor.run { self.scanError = error }
            } catch {
                await MainActor.run {
                    self.scanError = .openAIFailed(reason: error.localizedDescription)
                }
            }
        }
    }

    func retryLastScan() {
        guard let data = lastImageData, let image = lastUIImage else { return }
        beginScan(with: data, uiImage: image, includeDog: lastIncludeDog, includeCat: lastIncludeCat, includeChildren: lastIncludeChildren)
    }
}
