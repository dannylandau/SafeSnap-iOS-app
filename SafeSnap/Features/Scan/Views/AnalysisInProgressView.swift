import SwiftUI
import Combine

struct AnalysisInProgressView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage?
    @ObservedObject var viewModel: ScanViewModel

    // force read from the wrapped value, not the projected binding
    private var coordinator: ScanAnalysisCoordinator {
        _viewModel.wrappedValue.coordinator
    }
    let errorMessage: String?

    init(image: UIImage?, viewModel: ScanViewModel, errorMessage: String? = nil) {
        self.image = image
        self.viewModel = viewModel
        self.errorMessage = errorMessage
    }
    
    // MARK: - Step presentation
    private enum Step: CaseIterable { case vision, fast, smart }

    private func status(for step: Step) -> StepStatus {
        let current = coordinator.stage
        switch step {
        case .vision:
            if current == .vision { return .current }
            return current == .fast || current == .smart ? .done : .pending
        case .fast:
            if current == .fast { return .current }
            return current == .smart ? .done : .pending
        case .smart:
            return current == .smart ? .current : .pending
        }
    }

    private enum StepStatus { case pending, current, done }
    
    var body: some View {
        GeometryReader { geo in
            let maxWidth = geo.size.width
            let cardPadding: CGFloat = 24
            let imageSize = min(320, maxWidth - cardPadding * 2)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Image card
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: imageSize, height: imageSize)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .strokeBorder(.white.opacity(0.08))
                            )
                            .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 10)
                            .frame(maxWidth: .infinity)
                    }

                    // Indicator + steps card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Spacer()
                            AIBreathingIndicator(size: 88)
                            Spacer()
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            stepRow(title: "Vision",
                                    subtitle: coordinator.visionGuess?.description ?? "Reading labels & objects",
                                    status: status(for: .vision),
                                    duration: coordinator.visionDuration)
                            stepRow(title: "OpenAI – Fast",
                                    subtitle: coordinator.modelconfidence != nil
                                    ? "Confidence: \(coordinator.modelconfidence ?? 0)"
                                    : "Quick safety synthesis",
                                    status: status(for: .fast),
                                    duration: coordinator.fastDuration)
                            stepRow(title: "OpenAI – Smart",
                                    subtitle: "Deeper cross-checks",
                                    status: status(for: .smart),
                                    duration: coordinator.smartDuration)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .frame(maxWidth: .infinity)

                    // Copy
                    VStack(spacing: 8) {
                        Text("AI Analysis")
                            .font(.system(.title2, design: .rounded).weight(.semibold))
                            .frame(maxWidth: .infinity)

                        Text("Analyzing image for safety insights…")
                            .foregroundStyle(.green)
                            .font(.system(.body, design: .rounded))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Text("We're checking across multiple global safety standards to give you trustworthy results in just a few seconds.")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 4)

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.85))
                            .clipShape(Capsule())
                            .font(.footnote.bold())
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, cardPadding)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemBackground), Color(.systemGray6)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .interactiveDismissDisabled(false)
            .onDisappear {
                // If user swipes down to dismiss while work is ongoing, cancel as well
                if coordinator.isComplete == false {
                    viewModel.cancelScan()
                }
            }
        }
    }
    
    @ViewBuilder
    private func stepRow(title: String, subtitle: String, status: StepStatus, duration: Double? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            // Indicator
            switch status {
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .current:
                ZStack {
                    Circle().stroke(Color.accentColor.opacity(0.3), lineWidth: 3)
                        .frame(width: 20, height: 20)
                    Circle().fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                        .scaleEffect(1.2)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: UUID())
                }
            case .pending:
                Image(systemName: "circle.fill")
                    .foregroundStyle(.gray.opacity(0.3))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(status == .pending ? .secondary : .primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            if let duration {
                Text(String(format: "%.1fs", duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, alignment: .trailing)
            }
        }
    }
}


/// A calm, “AI thinking” indicator: a breathing orb with a soft expanding halo.
/// Drop-in replacement for a spinner.
struct AIBreathingIndicator: View {
    let size: CGFloat
    @State private var breathe = false
    @State private var haloPulse = false
    
    var body: some View {
        ZStack {
            // Expanding halo ring
            Circle()
                .stroke(Color.accentColor.opacity(0.28), lineWidth: size * 0.06)
                .frame(width: size, height: size)
                .scaleEffect(haloPulse ? 1.25 : 0.9)
                .opacity(haloPulse ? 0.0 : 1.0)
                .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: haloPulse)
            
            // Core orb (breathing)
            Circle()
                .fill(Color.accentColor)
                .frame(width: size * 0.22, height: size * 0.22)
                .shadow(radius: size * 0.08)
                .scaleEffect(breathe ? 1.18 : 0.92)
                .opacity(breathe ? 0.95 : 0.75)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: breathe)
            
            Circle()
                .stroke(Color.accentColor.opacity(0.18), lineWidth: size * 0.03)
                .frame(width: size * 0.5, height: size * 0.5)
                .blur(radius: size * 0.03)
        }
        .accessibilityLabel("Analyzing")
        .accessibilityValue("Working")
        .onAppear {
            breathe = true
            haloPulse = true
        }
    }
}
