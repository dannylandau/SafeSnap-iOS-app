import SwiftUI
import Combine

struct AnalysisInProgressView: View {
    let image: UIImage?
    @ObservedObject var coordinator: ScanAnalysisCoordinator

    init(image: UIImage?, coordinator: ScanAnalysisCoordinator) {
        self.image = image
        self.coordinator = coordinator
    }
    
    var body: some View {
        VStack(spacing: 32) {
            // Image with shadow & rounded corners
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 220, height: 220)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 8)
            }
            
            // Circular progress with eye icon
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.18), lineWidth: 6)
                    .frame(width: 70, height: 70)
                Circle()
                    .trim(from: 0.0, to: CGFloat(progressFraction(for: coordinator.currentPhase)))
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: coordinator.currentPhase)
                Image(systemName: "eye")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(Color.green)
            }
            
            VStack(spacing: 4) {
                Text("AI Analysis")
                    .font(.title.bold())
                Text("\u{1F4DD} Generating comprehensive safety report…")
                    .foregroundColor(Color.green)
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Processing Steps:")
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                ForEach(ScanPhase.allCases, id: \.self) { step in
                    HStack(alignment: .center, spacing: 8) {
                        statusIcon(for: step, current: coordinator.currentPhase)
                        Text(step.text)
                            .font(.footnote)
                            .fontWeight(step == coordinator.currentPhase ? .semibold : .regular)
                            .foregroundColor(color(for: step, current: coordinator.currentPhase))
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
    }
    
    // Helper: progress as fraction
    private func progressFraction(for phase: ScanPhase) -> Double {
        guard let idx = ScanPhase.allCases.firstIndex(where: { $0 == phase })
        else { return 0.1 }
        return Double(idx+1) / Double(PhaseSteps.allSteps.count)
    }
    
    // Helper: color for step
    private func color(for step: ScanPhase, current: ScanPhase) -> Color {
        if step == current { return .green }
        if PhaseSteps.isAfter(step, than: current) { return .secondary }
        return .primary
    }
    
    // Helper: status icon
    private func statusIcon(for step: ScanPhase, current: ScanPhase) -> some View {
        if step == current {
            return AnyView(
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .green))
                    .scaleEffect(0.7)
            )
        } else if PhaseSteps.isAfter(step, than: current) {
            return AnyView(Image(systemName: "circle.fill")
                .foregroundColor(.gray.opacity(0.32))
                .font(.system(size: 15)))
        } else {
            return AnyView(Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 15)))
        }
    }
}

struct PhaseSteps {
    static let allSteps: [ScanPhase] = ScanPhase.allCases
    static func isAfter(_ p1: ScanPhase, than p2: ScanPhase) -> Bool {
        guard let idx1 = allSteps.firstIndex(where: { $0 == p1 }),
              let idx2 = allSteps.firstIndex(where: { $0 == p2 }) else { return false }
        return idx1 > idx2
    }
}

// Add relevant ScanPhase values if not present
// (should match your analysis flow)
enum ScanPhase: CaseIterable, Equatable {
    case preparing
    case vision
    case detecting
    case openAI
    case identify
    case databases
    case openAISafety
    case petSafety
    case report

    var text: String {
        switch self {
        case .preparing: return "Preparing image for analysis..."
        case .vision: return "🔍 Connecting to Google Vision API..."
        case .detecting: return "🎯 Detecting objects and labels..."
        case .openAI: return "🤖 Running OpenAI Vision analysis..."
        case .identify: return "🎯 Identifying specific product details..."
        case .databases: return "🛡️ Checking safety databases (FDA, CPSC, EPA)..."
        case .openAISafety: return "🤖 Running OpenAI safety analysis..."
        case .petSafety: return "🐕🐈 Analyzing pet safety implications..."
        case .report: return "📝 Generating comprehensive safety report..."
        }
    }
}

// Preview
#Preview {
    AnalysisInProgressView(image: UIImage(systemName: "photo"), coordinator: ScanAnalysisCoordinator())
}
