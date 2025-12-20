//
//  ScanView.swift
//  Archie
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
    @StateObject private var viewModel: ScanViewModel
    @StateObject private var cameraViewModel: CameraViewModel
    @AppStorage("includeDogSafety") private var includeDog = false
    @AppStorage("includeCatSafety") private var includeCat = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isPhotoPickerPresented = false
    @State private var cameraState: CameraState = .hidden
    @State private var frozenFrame: UIImage?

    private let userSession: UserSession
    private let onShowHistory: () -> Void
    private let onShowAccount: () -> Void

    init(
        viewModel: ScanViewModel,
        userSession: UserSession,
        cameraViewModel: @autoclosure @escaping () -> CameraViewModel = CameraViewModel(),
        onShowHistory: @escaping () -> Void,
        onShowAccount: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _cameraViewModel = StateObject(wrappedValue: cameraViewModel())
        self.userSession = userSession
        self.onShowHistory = onShowHistory
        self.onShowAccount = onShowAccount
    }

    var body: some View {
        ZStack {
//            Color(uiColor: .systemGray6).ignoresSafeArea()

            Group {
                switch cameraState {
                case .hidden:
                    idleLayout
                case .live, .analyzing:
                    cameraLayout
                }
            }
        }
        .sheet(item: $viewModel.resultVM, onDismiss: {
            viewModel.resultVM = nil
            viewModel.phase = .idle
            resetCameraState()
        }) { vm in
            ResultView(vm: vm)
        }
        .alerts(using: viewModel.alerts)
        .photosPicker(isPresented: $isPhotoPickerPresented, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newItem in
            guard let item = newItem else { return }

            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        presentAnalyzingState(with: image)
                        viewModel.beginScan(with: data, uiImage: image, includeDog: includeDog, includeCat: includeCat, includeChildren: false)
                    }
                } catch {
                    #if DEBUG
                    print("Failed to load photo: \(error.localizedDescription)")
                    #endif
                }
                await MainActor.run {
                    selectedPhoto = nil
                    isPhotoPickerPresented = false
                }
            }
        }
        .onChange(of: cameraViewModel.capturedImage) { _, newImage in
            guard let image = newImage,
                  let data = image.jpegData(compressionQuality: 0.85) else { return }
            presentAnalyzingState(with: image)
            viewModel.beginScan(with: data, uiImage: image, includeDog: includeDog, includeCat: includeCat, includeChildren: false)
            cameraViewModel.capturedImage = nil
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            switch newPhase {
            case .result, .error:
                resetCameraState()
            default:
                break
            }
        }
    }

    private var idleLayout: some View {
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
                .padding(.bottom, 24)
            }

            ScanBottomControlsView(
                onCapture: handleCaptureTap,
                onGallery: handleGalleryTap
            )
        }
    }

    private var cameraLayout: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                cameraBackground(size: proxy.size)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    cameraTopBar(safeInsets: proxy.safeAreaInsets.top)
                        .padding(.horizontal, 20)

                    Spacer()

                    if cameraState == .live {
                        Text("Center the item inside the frame.\nTap the shutter when ready.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.bottom, 8)
                    } else {
//                        analyzingProgress
                    }

                    ScanBottomControlsView(
                        onCapture: handleCaptureTap,
                        onGallery: handleGalleryTap,
                        isCaptureDisabled: cameraState == .analyzing,
                        isGalleryDisabled: true
                    )
                }
            }
        }
    }

    private func cameraBackground(size: CGSize) -> some View {
        ZStack {
            if let frozenFrame {
                Image(uiImage: frozenFrame)
                    .resizable()
                    .scaledToFit()
                    .transition(.opacity)
            } else {
                CameraPreview(session: cameraViewModel.session)
                    .transition(.opacity)
            }

            Color.black.opacity(cameraState == .live ? 0.25 : 0.4)
                .ignoresSafeArea()

            ScanOverlayView(mode: cameraState == .analyzing ? .scanning : .framing, availableSize: size)
//                .padding(.horizontal, 32)
//                .padding(.top, 48)
        }
    }

    private func cameraTopBar(safeInsets: CGFloat) -> some View {
        HStack(spacing: 12) {
            Button(action: closeCamera) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(10)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Circle())
            }

            Spacer()

            Text(cameraState == .analyzing ? "Scanning…" : "Scanning Ready")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()
            Spacer().frame(width: 36)
        }
    }

    private func handleCaptureTap() {
        switch cameraState {
        case .hidden:
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                cameraState = .live
            }
        case .live:
            cameraViewModel.capturePhoto()
        case .analyzing:
            break
        }
    }

    private func handleGalleryTap() {
        guard cameraState == .hidden else { return }
        isPhotoPickerPresented = true
    }

    private func presentAnalyzingState(with image: UIImage) {
        frozenFrame = image
        withAnimation(.easeInOut(duration: 0.25)) {
            cameraState = .analyzing
        }
    }

    private func closeCamera() {
        if cameraState == .analyzing {
            viewModel.cancelScan()
        }
        resetCameraState()
    }

    private func resetCameraState() {
        withAnimation(.easeInOut(duration: 0.25)) {
            cameraState = .hidden
        }
        frozenFrame = nil
    }

    private enum CameraState {
        case hidden
        case live
        case analyzing
    }

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

private extension ScanView {
    var analyzingProgress: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                progressRow(
                    title: "Identifying product (Google Vision)",
                    isActive: viewModel.stage == .vision,
                    isComplete: viewModel.stage != .vision
                )
                if viewModel.stage != .vision {
                    VStack(alignment: .leading, spacing: 6) {
                        if let guess = viewModel.visionBestGuess, !guess.isEmpty {
                            Text("Vision best guess: \(guess)")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        if !viewModel.visionWebEntities.isEmpty {
                            Text("WebEntities:")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.visionWebEntities.prefix(8), id: \.self) { entity in
                                        Text(entity)
                                            .font(.caption)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
                                            .background(Color.white.opacity(0.15))
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                progressRow(
                    title: "Checking safety (Archie Safety Check)",
                    isActive: viewModel.stage == .fast,
                    isComplete: viewModel.stage == .smart
                )
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))


            if let partial = viewModel.partialStatus, !partial.isEmpty {
                Text(partial)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
        .padding(.bottom, 4)
    }

    func progressRow(title: String, isActive: Bool, isComplete: Bool) -> some View {
        HStack(spacing: 10) {
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if isActive {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.white.opacity(0.35))
            }

            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(isComplete ? 0.85 : 1.0))
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
