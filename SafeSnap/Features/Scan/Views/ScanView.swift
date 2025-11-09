//
//  ScanView.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//

import SwiftUI
import PhotosUI

enum ScanPhase: Equatable {
    case idle
    case analyzing(image: UIImage)
    case result(RecognitionResultViewModel)
    case error
    
    
    static func == (lhs: ScanPhase, rhs: ScanPhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.analyzing, .analyzing): return true
        case (.result, .result): return true
        case (.error, .error): return true
        default: return false
        }
    }
}

struct ScanView: View {
    // removed EnvironmentObject; not needed anymore
    @StateObject private var viewModel: ScanViewModel
    @AppStorage("includeDogSafety") private var includeDog = false
    @AppStorage("includeCatSafety") private var includeCat = false
    @State private var activeSheet: ActiveSheet? = nil
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isPhotoPickerPresented = false
    private let userSession: UserSession
    private let onShowHistory: () -> Void
    private let onShowAccount: () -> Void
    
    init(
        viewModel: ScanViewModel,
        userSession: UserSession,
        onShowHistory: @escaping () -> Void,
        onShowAccount: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.userSession = userSession
        self.onShowHistory = onShowHistory
        self.onShowAccount = onShowAccount
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(uiColor: .systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ScanHeroHeaderView(
                            userSession: userSession,
                            categories: ScanCategory.homeDefaults,
                            onHistory: onShowHistory,
                            onAccount: onShowAccount
                        )

                        PetSafetyCard(includeDog: $includeDog, includeCat: $includeCat)
#if DEBUG
                        debugControls
#endif
                    }
                }

                ScanBottomControlsView(
                    onCapture: { activeSheet = .camera },
                    onGallery: { isPhotoPickerPresented = true }
                )
            }
        }
        // Camera Sheet
        .sheet(item: $activeSheet) { sheet in
            if case .camera = sheet {
                CameraView { image in
                    if let data = image.jpegData(compressionQuality: 0.8) {
                        activeSheet = nil
                        viewModel.beginScan(with: data, uiImage: image, includeDog: includeDog, includeCat: includeCat, includeChildren: false)
                    } else {
                        print("⚠️ Failed to convert UIImage to JPEG data")
                    }
                }
            }
        }
        .sheet(isPresented: .constant(viewModel.phase.isAnalyzing), onDismiss: {
            if case .analyzing(_) = viewModel.phase {
                viewModel.cancelScan()
            }
        }) {
            if case let .analyzing(image) = viewModel.phase {
                AnalysisInProgressView(image: image, viewModel: viewModel)
            }
        }
        .sheet(item: $viewModel.resultVM, onDismiss: {
            viewModel.resultVM = nil
        }) { vm in
            ResultView(vm: vm)
        }
        .alerts(using: viewModel.alerts)
        .photosPicker(isPresented: $isPhotoPickerPresented, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newItem in
            guard let item = newItem else {
                return
            }

            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        viewModel.beginScan(with: data, uiImage: image, includeDog: includeDog, includeCat: includeCat, includeChildren: false)
                    }
                } catch {
                    print("Failed to load photo: \(error.localizedDescription)")
                }
                await MainActor.run {
                    selectedPhoto = nil
                    isPhotoPickerPresented = false
                }
            }
        }
    }
    
    // Computed property to check if the current phase is analyzing
    // (moved to ScanPhase extension below)
    
    

#if DEBUG
    private var debugControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Debug")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Toggle(isOn: Binding(
                get: { viewModel.scanDurationEnabled },
                set: { viewModel.setScanDurationTrackingEnabled($0) }
            )) {
                Label("Show scan duration timer", systemImage: "timer")
            }
            .toggleStyle(.switch)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
#endif
}

private enum ActiveSheet: Identifiable {
    case camera
    var id: Int { hashValue }
}

// Extension to ScanPhase to check if it's analyzing
private extension ScanPhase {
    var isAnalyzing: Bool {
        if case .analyzing = self { return true }
        return false
    }
}
