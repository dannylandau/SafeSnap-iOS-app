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
    @Published var phase: ScanPhase = .idle
    @Published var scanError: ScanError? = nil
    
    @MainActor let alerts = AlertCenter()

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
                await MainActor.run {
                    self.phase = .error
                    self.scanError = error
                    print(error.localizedDescription)
                    alerts.show(AppAlert.from(error: error, retry: {
                        [weak self] in self?.retryLastScan()
                    }))
                }
            } catch {
                await MainActor.run {
                    self.phase = .error
                    self.scanError = .openAIFailed(reason: error.localizedDescription)
                    print(error.localizedDescription)
                    alerts.show(AppAlert.from(error: error, retry: {
                        [weak self] in self?.retryLastScan()
                    }))
                }
            }
        }
    }

    func retryLastScan() {
        guard let data = lastImageData, let image = lastUIImage else { return }
        beginScan(with: data, uiImage: image, includeDog: lastIncludeDog, includeCat: lastIncludeCat, includeChildren: lastIncludeChildren)
    }
    
    func cancelScan() {
        Task { @MainActor in
            self.coordinator.cancelAnalysis()
            self.phase = .idle
            self.resultVM = nil
            self.scanError = nil
            self.lastImageData = nil
            self.lastUIImage = nil
        }
    }
}
