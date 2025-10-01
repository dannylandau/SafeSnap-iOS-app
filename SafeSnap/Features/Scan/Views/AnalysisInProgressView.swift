import SwiftUI
import Combine

struct AnalysisInProgressView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage?
    @ObservedObject var viewModel: ScanViewModel

    private let coordinator: ScanAnalysisCoordinating
    private let concreteCoordinator: ScanAnalysisCoordinator?
    @State private var observedStage: SafetyAnalyzer.Stage
    @State private var observedVisionDuration: Double?
    @State private var observedFastDuration: Double?
    @State private var observedSmartDuration: Double?
    let errorMessage: String?

    init(image: UIImage?, viewModel: ScanViewModel, errorMessage: String? = nil) {
        self.image = image
        self.viewModel = viewModel
        self.errorMessage = errorMessage
        let coordinator = viewModel.coordinator
        self.coordinator = coordinator
        let concrete = coordinator as? ScanAnalysisCoordinator
        self.concreteCoordinator = concrete
        _observedStage = State(initialValue: concrete?.stage ?? .vision)
        _observedVisionDuration = State(initialValue: concrete?.visionDuration)
        _observedFastDuration = State(initialValue: concrete?.fastDuration)
        _observedSmartDuration = State(initialValue: concrete?.smartDuration)
    }
    
    // MARK: - Step presentation
    private enum Step: CaseIterable { case visionScan, geminiScoring }

    private func status(for step: Step) -> StepStatus {
        let currentStage = observedStage
        switch step {
        case .visionScan:
            return currentStage == .vision ? .current : .done
        case .geminiScoring:
            if currentStage == .vision { return .pending }
            if currentStage == .smart { return .done }
            switch viewModel.phase {
            case .result, .error:
                return .done
            default:
                return .current
            }
        }
    }

    private func title(for step: Step) -> String {
        switch step {
        case .visionScan:
            return "Scanning photo details"
        case .geminiScoring:
            return "Evaluating safety insights"
        }
    }

    private func subtitle(for step: Step) -> String {
        switch step {
        case .visionScan:
            return "Google Vision is identifying labels, text, and brands."
        case .geminiScoring:
            return "Gemini is scoring the product for kids and pets."
        }
    }

    private func duration(for step: Step) -> Double? {
        switch status(for: step) {
        case .pending, .current:
            return nil
        case .done:
            switch step {
            case .visionScan:
                return observedVisionDuration
            case .geminiScoring:
                return observedSmartDuration ?? observedFastDuration
            }
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
                        stepProgress
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
            .onReceive(stagePublisher) { observedStage = $0 }
            .onReceive(visionDurationPublisher) { observedVisionDuration = $0 }
            .onReceive(fastDurationPublisher) { observedFastDuration = $0 }
            .onReceive(smartDurationPublisher) { observedSmartDuration = $0 }
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

    private var stepProgress: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Step.allCases, id: \.self) { step in
                stepRow(
                    title: title(for: step),
                    subtitle: subtitle(for: step),
                    status: status(for: step),
                    duration: duration(for: step)
                )
            }
        }
    }

    private var stagePublisher: AnyPublisher<SafetyAnalyzer.Stage, Never> {
        concreteCoordinator?.$stage.eraseToAnyPublisher() ?? Empty<SafetyAnalyzer.Stage, Never>().eraseToAnyPublisher()
    }

    private var visionDurationPublisher: AnyPublisher<Double?, Never> {
        concreteCoordinator?.$visionDuration.eraseToAnyPublisher() ?? Empty<Double?, Never>().eraseToAnyPublisher()
    }

    private var fastDurationPublisher: AnyPublisher<Double?, Never> {
        concreteCoordinator?.$fastDuration.eraseToAnyPublisher() ?? Empty<Double?, Never>().eraseToAnyPublisher()
    }

    private var smartDurationPublisher: AnyPublisher<Double?, Never> {
        concreteCoordinator?.$smartDuration.eraseToAnyPublisher() ?? Empty<Double?, Never>().eraseToAnyPublisher()
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
