//
//  RecognitionResultViewModel.swift
//  SafeSnap
//
//  Re-implemented to support focused score selection, persistence,
//  and a consistent 0–100 → 0–10 scoring model for the UI.
//

import SwiftUI
import UIKit

// MARK: — ViewModel
final class RecognitionResultViewModel: ObservableObject, Identifiable {
    // MARK: Focus selection (persisted)
    enum FocusSection: String { case children, dogs, cats }

    @Published var selectedSection: FocusSection = .children {
        didSet {
            UserDefaults.standard.set(selectedSection.rawValue, forKey: selectionKey)
        }
    }

    private var selectionKey: String = "ResultSelectedSection:default"

    // MARK: Identity & base data
    let id = UUID()
    let image: UIImage?
    let productName: String
    let category: String
    let date: Date
    
    // Persisted image (filename-only for durability across reinstalls)
    let imageFilename: String?
    var imageRef: URL? {
        guard let name = imageFilename else { return nil }
        let fm = FileManager.default
        if let docs = try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            let imagesDir = docs.appendingPathComponent("Images", isDirectory: true)
            return imagesDir.appendingPathComponent(name)
        }
        return nil
    }


    // Keep the structured response
    let analysis: SafetyAnalysisResponse

    // User toggles
    let includeDogs: Bool
    let includeCats: Bool

    // Derived lists for UI
    var safeBenefits: [String] { analysis.generalSafety.pros.map { $0.label } }
    var safetyConcerns: [String] { analysis.generalSafety.cons.map { $0.label } }
    var dataSources: [String] { analysis.recalls.map { $0.source } }

    // Pet warnings unpacked for convenience
    var dogWarnings: [(severity: String, warning: String, reason: String)] {
        analysis.petSafety.dogs.map { ($0.severity.rawValue, $0.warning, $0.reason) }
    }
    var catWarnings: [(severity: String, warning: String, reason: String)] {
        analysis.petSafety.cats.map { ($0.severity.rawValue, $0.warning, $0.reason) }
    }

    // MARK: — Scores
    /// The overall score (0–100) to display, driven by the user's selected focus.
    var overallScoreHundred: Int {
        switch selectedSection {
        case .children:
            return analysis.childSafetyScore
        case .dogs:
            return analysis.dogSafetyScore ?? analysis.childSafetyScore
        case .cats:
            return analysis.catSafetyScore ?? analysis.childSafetyScore
        }
    }

    /// The UI commonly expects a /10 score; compute it from the selected overall.
    var score: Int { Self.score10(fromHundred: overallScoreHundred) }

    /// Human label for the /10 score.
    var safetyLabel: String { Self.label(for: score) }

    // MARK: — Lifecycle
    init(
        image: UIImage?,
        productName: String,
        category: String,
        date: Date,
        analysis: SafetyAnalysisResponse,
        includeDogs: Bool,
        includeCats: Bool,
        imageFilename: String? = nil
    ) {
        self.image = image
        self.productName = productName
        self.category = category
        self.date = date
        self.analysis = analysis
        self.includeDogs = includeDogs
        self.includeCats = includeCats
        self.imageFilename = imageFilename

        // Build a stable per-analysis key without mutating the server schema.
        self.selectionKey = Self.makeSelectionKey(for: analysis)
        if let raw = UserDefaults.standard.string(forKey: selectionKey),
           let persisted = FocusSection(rawValue: raw) {
            self.selectedSection = persisted
        }
    }
}

extension RecognitionResultViewModel {
    /// Create a stable key for persisting UI preferences for a specific analysis
    /// without changing the server-side schema. Uses a compact base64 of salient fields.
    static func makeSelectionKey(for a: SafetyAnalysisResponse) -> String {
        let base = "\(a.productName)|\(a.productType)|\(a.overallSafetyScore)|\(a.childSafetyScore)|\(a.dogSafetyScore ?? -1)|\(a.catSafetyScore ?? -1)"
        let token = Data(base.utf8).base64EncodedString()
        return "ResultSelectedSection:\(token)"
    }
}

// MARK: — Convenience initializers & helpers
extension RecognitionResultViewModel {
    convenience init(image: UIImage?, from item: ScanHistoryItem) {
        self.init(
            image: image,
            productName: item.productName,
            category: item.categoryName,
            date: item.createdAt,
            analysis: item.analysis,
            includeDogs: item.userToggles.includeDogs,
            includeCats: item.userToggles.includeCats,
            imageFilename: item.imageFilename
        )
    }

    /// Map a /10 score to a label used in the UI.
    static func label(for score10: Int) -> String {
        switch score10 {
        case 9...10: return "Very Safe"
        case 7...8:  return "Safe"
        case 5...6:  return "Use with Care"
        case 3...4:  return "Risky"
        default:     return "Dangerous"
        }
    }

    /// Convert 0–100 → 0–10 (rounded).
    static func score10(fromHundred value: Int) -> Int {
        let clamped = max(0, min(100, value))
        return Int(round(Double(clamped) / 10.0))
    }
}
