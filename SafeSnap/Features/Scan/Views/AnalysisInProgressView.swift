import SwiftUI
import Combine

struct AnalysisInProgressView: View {
    let image: UIImage?
    @ObservedObject var coordinator: ScanAnalysisCoordinator
    let errorMessage: String?

    init(image: UIImage?, coordinator: ScanAnalysisCoordinator, errorMessage: String? = nil) {
        self.image = image
        self.coordinator = coordinator
        self.errorMessage = errorMessage
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 40)

            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 280, height: 280)
                    .background(
                        RoundedRectangle(cornerRadius: 56, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .background(.ultraThinMaterial)
                            .blur(radius: 8)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 56, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 10)
                    .padding(.bottom, 28)
            }

            SpinnerView()
                .frame(height: 24)
                .padding(.bottom, 28)

            VStack(spacing: 10) {
                Text("AI Analysis")
                    .font(.system(.title2, design: .rounded).weight(.semibold))

                Text("Analyzing image for safety insights…")
                    .foregroundStyle(.green)
                    .font(.system(.body, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("We're checking across multiple global safety standards to give you trustworthy results in just a few seconds.")
                    .foregroundColor(.secondary)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.85))
                    .clipShape(Capsule())
                    .font(.footnote.bold())
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(.systemBackground), Color(.systemGray6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
    
    // Helper: progress as fraction
//    private func progressFraction(for phase: ScanStepPhase) -> Double {
//        guard let idx = ScanStepPhase.allCases.firstIndex(where: { $0 == phase })
//        else { return 0.1 }
//        return Double(idx+1) / Double(PhaseSteps.allSteps.count)
//    }
    
//    // Helper: color for step
//    private func color(for step: ScanStepPhase, current: ScanStepPhase) -> Color {
//        if step == current { return .green }
//        if PhaseSteps.isAfter(step, than: current) { return .secondary }
//        return .primary
//    }
//    
//    // Helper: status icon
//    private func statusIcon(for step: ScanStepPhase, current: ScanStepPhase) -> some View {
//        if step == current {
//            return AnyView(
//                ProgressView()
//                    .progressViewStyle(CircularProgressViewStyle(tint: .green))
//                    .scaleEffect(0.7)
//            )
//        } else if PhaseSteps.isAfter(step, than: current) {
//            return AnyView(Image(systemName: "circle.fill")
//                .foregroundColor(.gray.opacity(0.32))
//                .font(.system(size: 15)))
//        } else {
//            return AnyView(Image(systemName: "checkmark.circle.fill")
//                .foregroundColor(.green)
//                .font(.system(size: 15)))
//        }
//    }
}

//struct PhaseSteps {
//    static let allSteps: [ScanStepPhase] = ScanStepPhase.allCases
//    static func isAfter(_ p1: ScanStepPhase, than p2: ScanStepPhase) -> Bool {
//        guard let idx1 = allSteps.firstIndex(where: { $0 == p1 }),
//              let idx2 = allSteps.firstIndex(where: { $0 == p2 }) else { return false }
//        return idx1 > idx2
//    }
//}

struct SpinnerView: View {
    @State private var rotateOuter = false
    @State private var rotateInner = false
    @State private var scalePulse = false

    var body: some View {
        ZStack {
            // Pulsing glowing circle
            Circle()
                .fill(Color.green.opacity(0.15))
                .frame(width: 90, height: 90)
                .scaleEffect(scalePulse ? 1.1 : 0.95)
                .animation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: scalePulse)

            // Outer glowing arc
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(
                    AngularGradient(gradient: Gradient(colors: [Color.green, Color.green.opacity(0.3)]), center: .center),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: 80, height: 80)
                .blur(radius: 2)
                .rotationEffect(.degrees(rotateOuter ? 360 : 0))
                .animation(Animation.linear(duration: 2.5).repeatForever(autoreverses: false), value: rotateOuter)

            // Inner fast rotating arc
            Circle()
                .trim(from: 0.0, to: 0.2)
                .stroke(
                    AngularGradient(gradient: Gradient(colors: [Color.green.opacity(0.6), Color.green]), center: .center),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(rotateInner ? 360 : 0))
                .animation(Animation.linear(duration: 0.8).repeatForever(autoreverses: false), value: rotateInner)

            // Central dot
            Circle()
                .fill(Color.green)
                .frame(width: 12, height: 12)
                .shadow(color: Color.green.opacity(0.6), radius: 6, x: 0, y: 0)
        }
        .onAppear {
            rotateOuter = true
            rotateInner = true
            scalePulse = true
        }
    }
}



// Preview
//#Preview {
//    AnalysisInProgressView(image: UIImage(systemName: "photo"), coordinator: ScanAnalysisCoordinator())
//}
