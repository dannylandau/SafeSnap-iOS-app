//
//  ScanView.swift
//  Archie
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//

import SwiftUI
import Photos
import PhotosUI
import AVFoundation
import UIKit

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
    @AppStorage("didShowLimitedPhotosAlert") private var didShowLimitedPhotosAlert = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isPhotoPickerPresented = false
    @State private var cameraState: CameraState = .hidden
    @State private var frozenFrame: UIImage?
    @State private var pendingPreviewFreeze = false
    @State private var shutterFlashOpacity = 0.0

    private let userSession: UserSession
    private let onShowHistory: () -> Void
    private let onShowAccount: () -> Void

    init(
        viewModel: ScanViewModel,
        userSession: UserSession,
        cameraViewModel: @autoclosure @escaping () -> CameraViewModel = CameraViewModel(startSession: false),
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
        .onChange(of: cameraViewModel.previewImage) { _, newImage in
            guard pendingPreviewFreeze, let image = newImage else { return }
            presentAnalyzingState(with: image)
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
                onHome: handleHomeTap,
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
                        onHome: handleHomeTap,
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

            Color.white
                .opacity(shutterFlashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private func cameraTopBar(safeInsets: CGFloat) -> some View {
        HStack(spacing: 12) {
            Button(action: closeCamera) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
            }

            Spacer()

            Text(cameraState == .analyzing ? "Scanning…" : "Scanning Ready")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()
            Spacer().frame(width: 36)
        }
    }
    
    private func handleHomeTap() {
        //no-op
    }

    private func handleCaptureTap() {
        switch cameraState {
        case .hidden:
            requestCameraAccessIfNeeded()
        case .live:
            pendingPreviewFreeze = true
            triggerShutterFlash()
            cameraViewModel.requestPreviewFrame()
            cameraViewModel.capturePhoto()
        case .analyzing:
            break
        }
    }

    private func handleGalleryTap() {
        guard cameraState == .hidden else { return }
        requestPhotoAccessIfNeeded()
    }

    private func presentAnalyzingState(with image: UIImage) {
        pendingPreviewFreeze = false
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
        pendingPreviewFreeze = false
        shutterFlashOpacity = 0
    }

    private func triggerShutterFlash() {
        shutterFlashOpacity = 0
        withAnimation(.easeOut(duration: 0.08)) {
            shutterFlashOpacity = 0.85
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeOut(duration: 0.2)) {
                shutterFlashOpacity = 0
            }
        }
    }

    private func requestCameraAccessIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    granted ? startCamera() : showCameraDeniedAlert()
                }
            }
        case .denied, .restricted:
            showCameraDeniedAlert()
        @unknown default:
            showCameraDeniedAlert()
        }
    }

    private func startCamera() {
        cameraViewModel.setupSession()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            cameraState = .live
        }
    }

    private func showCameraDeniedAlert() {
        viewModel.alerts.show(
            AppAlert(
                title: "Camera Access Needed",
                message: "Enable camera access in Settings to scan products.",
                actions: [
                    .init(title: "Open Settings", role: .normal, perform: openAppSettings),
                    .init(title: "Cancel", role: .cancel)
                ]
            )
        )
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func requestPhotoAccessIfNeeded() {
        handlePhotoAuthorizationStatus(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    private func handlePhotoAuthorizationStatus(_ status: PHAuthorizationStatus) {
        switch status {
        case .authorized:
            isPhotoPickerPresented = true
        case .limited:
            if didShowLimitedPhotosAlert {
                isPhotoPickerPresented = true
            } else {
                didShowLimitedPhotosAlert = true
                showLimitedPhotosAlert()
            }
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    handlePhotoAuthorizationStatus(newStatus)
                }
            }
        case .denied, .restricted:
            showPhotosDeniedAlert()
        @unknown default:
            showPhotosDeniedAlert()
        }
    }

    private func showLimitedPhotosAlert() {
        viewModel.alerts.show(
            AppAlert(
                title: "Limited Photos Access",
                message: "You can choose from the photos already shared with Archie, or add more.",
                actions: [
                    .init(title: "Choose Photos", role: .normal, perform: { isPhotoPickerPresented = true }),
                    .init(title: "Manage Photos", role: .normal, perform: presentLimitedLibraryPicker),
                    .init(title: "Cancel", role: .cancel)
                ]
            )
        )
    }

    private func showPhotosDeniedAlert() {
        viewModel.alerts.show(
            AppAlert(
                title: "Photos Access Needed",
                message: "Enable photo access in Settings to pick a product image.",
                actions: [
                    .init(title: "Open Settings", role: .normal, perform: openAppSettings),
                    .init(title: "Cancel", role: .cancel)
                ]
            )
        )
    }

    private func presentLimitedLibraryPicker() {
        guard let presenter = UIApplication.safesnapKeyWindow?.rootViewController?.topMostViewController else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: presenter)
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

