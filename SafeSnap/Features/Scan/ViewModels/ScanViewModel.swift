//
//  ScanViewModel.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 22/07/2025.
//

import Foundation
import PhotosUI
import SwiftUI

@MainActor
protocol ScanAnalysisCoordinating: AnyObject {
    func startGeminiScan(image: UIImage, options: SafetyOptions) async throws
    func cancelAnalysis()
    var latestHistoryItem: ScanHistoryItem? { get }
    var stage: SafetyAnalyzer.Stage { get }
}

extension ScanAnalysisCoordinator: ScanAnalysisCoordinating {}

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

    let coordinator: ScanAnalysisCoordinating

    init(coordinator: ScanAnalysisCoordinating) {
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
        lastIncludeDog = includeDog
        lastIncludeCat = includeCat
        lastIncludeChildren = includeChildren

        Task {
            do {
                try await coordinator.startGeminiScan(
                    image: uiImage,
                    options: SafetyOptions(includeDogs: includeDog, includeCats: includeCat, includeChildren: includeChildren)
                )
                if let result = await coordinator.latestHistoryItem {
                    let viewModel = RecognitionResultViewModel(image: uiImage, from: result)
                    await MainActor.run {
                        self.resultVM = viewModel
                        self.phase = .result(viewModel)
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.phase = .idle
                }
            } catch let error as ScanError {
                if error.localizedDescription.contains("Recognition confidence too low") {
                    await MainActor.run {
                        self.phase = .idle
                        self.resultVM = nil
                        self.scanError = nil
                        self.showLowRecognitionRetakeAlert()
                    }
                    return
                }
                await MainActor.run {
                    self.phase = .error
                    self.scanError = error
                    print(error.localizedDescription)
                    alerts.show(AppAlert.from(error: error, retry: {
                        [weak self] in self?.retryLastScan()
                    }))
                }
            } catch {
                if error.localizedDescription.contains("Recognition confidence too low") {
                    await MainActor.run {
                        self.phase = .idle
                        self.resultVM = nil
                        self.scanError = nil
                        self.showLowRecognitionRetakeAlert()
                    }
                    return
                }
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

    @MainActor
    private func showLowRecognitionRetakeAlert() {
        let tips = """
        Can't recognize the product clearly.

        Try:
        • Scan the product label
        • Center the object
        • Photograph the front of the package
        """
        // Show alert with a Retake primary action (reset to idle so the user can reshoot)
        alerts.show(
            AppAlert(title: "Need a clearer photo",
                     message: tips,
                     actions: [
                        .init(title: "Retake",
                              role: .normal,
                              perform: { [weak self] in
                                  self?.cancelScan()
                              }),
                        .init(title: "Dismiss",
                              role: .cancel,
                              perform: {})
                     ])
        )
    }

    func retryLastScan() {
        guard let data = lastImageData, let image = lastUIImage else { return }
        beginScan(with: data, uiImage: image, includeDog: lastIncludeDog, includeCat: lastIncludeCat, includeChildren: lastIncludeChildren)
    }
    
    func cancelScan() {
        print("🛑 Cancelling scan")
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
