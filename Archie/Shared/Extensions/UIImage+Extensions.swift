//
//  UIImage+Extensions.swift
//  Archie
//
//  Created by Marcin Grześkowiak on 08/08/2025.
//

import SwiftUI

extension UIImage {
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
