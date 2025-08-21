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
//    @State private var currentPhase: ScanPhase = .vision

    var body: some View {
        ZStack {
            CameraPreview(session: viewModel.session)
                .ignoresSafeArea()

            VStack {
                Capsule()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                Spacer()
            }

            ZStack {
                ScanCornersOverlay()
                    .frame(width: 240, height: 240)

                if isAnalyzing {
                    ScanLineOverlay()
                        .frame(width: 240, height: 240)
                        .transition(.opacity)
                        .animation(.easeInOut, value: isAnalyzing)

                    Text("Scanning...")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 280)
                }
            }

            VStack(spacing: 16) {
                Text("Make sure the object fills the frame to improve scan accuracy.")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button(action: viewModel.capturePhoto) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                        .shadow(radius: 10)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .onChange(of: viewModel.capturedImage) { _, newValue in
            guard let image = newValue else { return }
            isAnalyzing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                onImageCaptured(image)
                presentationMode.wrappedValue.dismiss()
            }
        }
        .onAppear {
            viewModel.setupSession()
        }
    }
}

struct ScanCornersOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let size: CGFloat = 24
            let stroke: CGFloat = 4

            Path { path in
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: size, y: 0))
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: 0, y: size))

                path.move(to: CGPoint(x: geo.size.width, y: 0))
                path.addLine(to: CGPoint(x: geo.size.width - size, y: 0))
                path.move(to: CGPoint(x: geo.size.width, y: 0))
                path.addLine(to: CGPoint(x: geo.size.width, y: size))

                path.move(to: CGPoint(x: 0, y: geo.size.height))
                path.addLine(to: CGPoint(x: 0, y: geo.size.height - size))
                path.move(to: CGPoint(x: 0, y: geo.size.height))
                path.addLine(to: CGPoint(x: size, y: geo.size.height))

                path.move(to: CGPoint(x: geo.size.width, y: geo.size.height))
                path.addLine(to: CGPoint(x: geo.size.width - size, y: geo.size.height))
                path.move(to: CGPoint(x: geo.size.width, y: geo.size.height))
                path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height - size))
            }
            .stroke(Color.white, lineWidth: stroke)
        }
    }
}

struct ScanLineOverlay: View {
    @State private var offset: CGFloat = -120

    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.3))
            .frame(height: 2)
            .offset(y: offset)
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    offset = 120
                }
            }
    }
}
