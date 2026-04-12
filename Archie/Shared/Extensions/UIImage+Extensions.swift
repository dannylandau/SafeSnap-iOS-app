//
//  UIImage+Extensions.swift
//  Archie
//
//  Created by Marcin Grześkowiak on 08/08/2025.
//

import SwiftUI

extension UIImage {
    func resizedToFit(maxPixelSize: CGFloat) -> UIImage {
        let pixelWidth = size.width * scale
        let pixelHeight = size.height * scale
        guard pixelWidth > 0, pixelHeight > 0 else { return self }

        let maxEdge = max(pixelWidth, pixelHeight)
        guard maxEdge > maxPixelSize else { return self }

        let scaleFactor = maxPixelSize / maxEdge
        let targetWidth = max(1, floor(pixelWidth * scaleFactor))
        let targetHeight = max(1, floor(pixelHeight * scaleFactor))
        let targetSize = CGSize(width: targetWidth, height: targetHeight)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    func resizedThumbnail(maxSize: CGFloat = 200) -> UIImage? {
        let aspectRatio = size.width / size.height

        var newSize: CGSize
        if aspectRatio > 1 {
            // Landscape
            newSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            // Portrait or square
            newSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
