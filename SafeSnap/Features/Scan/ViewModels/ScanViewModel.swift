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
    @Published var selectedItem: PhotosPickerItem? {
        didSet { loadImageFromPicker() }
    }
    
    @Published var resultVM: RecognitionResultViewModel? = nil
    
    enum ScanPhase: Equatable {
        case idle
        case analyzing(image: UIImage)
        case result(RecognitionResultViewModel)
        
        
        static func == (lhs: ScanPhase, rhs: ScanPhase) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.analyzing, .analyzing): return true
            case (.result, .result): return true
            default: return false
            }
        }
    }

    @Published var phase: ScanPhase = .idle
    private var hasCompleted = false

    private let historyService: ScanHistoryService
    private let analysisService: ImageAnalysisService

    init(historyService: ScanHistoryService, analysisService: ImageAnalysisService = MockImageAnalysisService()) {
        self.historyService = historyService
        self.analysisService = analysisService
    }

    func handleImage(_ image: UIImage) {
        print("Handling image from picker or camera: \(image)")
        hasCompleted = false
        resultVM = nil
        phase = .analyzing(image: image)
    }

    @MainActor
    func completeAnalysis() async {
        guard !hasCompleted else { return }
        hasCompleted = true
        guard case let .analyzing(img) = phase else { return }

        let result = await analysisService.analyze(image: img)
        historyService.add(result.historyItem)
        self.phase = .result(result.resultVM)
        self.resultVM = result.resultVM
        hasCompleted = false // prepare for next scan
    }

    private func loadImageFromPicker() {
        guard let item = selectedItem else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let ui = UIImage(data: data) {
                await MainActor.run {
                    self.handleImage(ui)
                }
            }
        }
    }
}
