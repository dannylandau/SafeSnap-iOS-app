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
        // Input absolute URL; persisted as filename only (container-safe)
        imageRef: URL,
        imageData: Data,
        userToggles: ScanHistoryItem.UserToggles,
        visionContextRef: URL?,
        model: String = "gpt-4o",
        promptVersion: String = "v1",
        appVersion: String = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    ) -> ScanHistoryItem {
        let hash = sha256Hex(imageData)
        return ScanHistoryItem(
            imageFilename: imageRef.lastPathComponent,
            imageHash: hash,
            userToggles: userToggles,
            productName: analysis.productName,
            productType: analysis.productType,
            categoryName: analysis.productType,
            brand: product.brandCandidates.first,
            confidence: product.confidence,
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
