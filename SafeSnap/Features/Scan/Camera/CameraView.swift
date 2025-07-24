//
//  CameraView.swift
//  SafeSnap
//
import SwiftUI

struct CameraView: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var viewModel = CameraViewModel()

    /// 1️⃣ Callback to parent when an image is ready
    let onImageCaptured: (UIImage) -> Void

    /// Internal loading / analysis state
    @State private var isAnalyzing = false
    @State private var currentPhase: ScanPhase = .vision

    var body: some View {
        ZStack {
            // Camera feed
            CameraPreview(session: viewModel.session)
                .ignoresSafeArea()

            // Capture button
            VStack {
                Spacer()
                Button(action: viewModel.capturePhoto) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                        .shadow(radius: 10)
                }
                .padding(.bottom, 32)
            }

            // Loading overlay while analyzing
            if isAnalyzing {
                Color.black.opacity(0.4).ignoresSafeArea()
                ScanProgressView(phase: currentPhase)
            }
        }
        .onChange(of: viewModel.capturedImage) { _, newValue in
            guard let image = newValue else { return }
            analyze(image)
        }
        .onAppear {
            viewModel.setupSession()
        }
    }

    // MARK: – Run your pipeline, then notify parent
    private func analyze(_ image: UIImage) {
        isAnalyzing = true

        RecognitionCoordinator.analyze(
            image: image,
            onPhaseChange: { phase in
                currentPhase = phase
            },
            completion: { result in
                isAnalyzing = false

                // 2️⃣ If you also want to show your internal sheet for results/not-found,
                //    you could still do it here, but since parent handles it, we just call:
                onImageCaptured(image)

                // 3️⃣ Dismiss the camera view immediately
                presentationMode.wrappedValue.dismiss()
            }
        )
    }
}
