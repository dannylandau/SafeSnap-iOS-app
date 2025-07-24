//
//  ScanHistoryItem.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 14/07/2025.
//


import Foundation
import UIKit

struct ScanHistoryItem: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let product: Product        // assuming your existing Product is Codable
    let labels: [String]
    let score: Int
    let thumbnailData: Data?    // small JPG/PNG for list thumbnail

    // Convenience thumbnail image
    var thumbnail: UIImage? {
        guard let data = thumbnailData else { return nil }
        return UIImage(data: data)
    }

    init(
        product: Product,
        labels: [String],
        score: Int,
        thumbnail: UIImage? = nil
    ) {
        self.id = .init()
        self.date = .now
        self.product = product
        self.labels = labels
        self.score = score
        self.thumbnailData = thumbnail?.jpegData(compressionQuality: 0.3)
    }
}
