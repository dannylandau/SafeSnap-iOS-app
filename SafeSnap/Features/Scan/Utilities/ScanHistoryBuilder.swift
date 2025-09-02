//
//  ScanHistoryBuilder.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 20/08/2025.
//


//  Utilities/ScanHistoryBuilder.swift
import Foundation
import CryptoKit

enum ScanHistoryBuilder {
    static func build(
        product: ProductIdentification,
        analysis: SafetyAnalysisResponse,
        imageRef: URL?,
        imageData: Data?,
        userToggles: ScanHistoryItem.UserToggles,
        signals: ScanHistoryItem.SignalsSummary,
        visionContextRef: URL?,
        model: String = "gpt-4o",
        promptVersion: String = "v1",
        appVersion: String = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    ) -> ScanHistoryItem {
        let hash = imageData.map { sha256Hex($0) } ?? ""
        return ScanHistoryItem(
            imageRef: imageRef,
            imageHash: hash,
            userToggles: userToggles,
            productName: analysis.productName,
            productType: analysis.productType,
            categoryName: analysis.productType,
            brand: product.brandCandidates.first,
            confidence: product.confidence,
            signalsSummary: signals,
            visionContextRef: visionContextRef,
            analysis: analysis,
            model: model,
            promptVersion: promptVersion,
            appVersion: appVersion
        )
    }

    private static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
