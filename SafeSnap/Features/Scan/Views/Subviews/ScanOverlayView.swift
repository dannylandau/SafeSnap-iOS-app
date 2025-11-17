//
//  ScanOverlayView.swift
//  SafeSnap
//

import SwiftUI

struct ScanOverlayView: View {
    enum Mode {
        case framing
        case scanning
    }

    let mode: Mode
    let availableSize: CGSize

    private let minSide: CGFloat = 220
    private let horizontalPadding: CGFloat = 64    // must match parent padding (32 each side)
    private let verticalAllowance: CGFloat = 320   // space reserved for top text + bottom controls

    var body: some View {
        // Keep the overlay within the safe area by honoring both proportional and absolute limits.
        let widthBound = max(min(availableSize.width * 0.78, availableSize.width - horizontalPadding), minSide)
        let heightBound = max(min(availableSize.height * 0.58, availableSize.height - verticalAllowance), minSide)
        let square = max(min(widthBound, heightBound), minSide)

        ZStack {
            ScanCornersOverlay()
                .stroke(Color.white.opacity(0.95), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: square, height: square*1.5)

            if mode == .scanning {
                ScanSweepLine(side: square*1.5)
                    .frame(width: square, height: square*1.5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ScanCornersOverlay: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerLength: CGFloat = min(rect.width, rect.height) * 0.16

        // Top-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY))

        // Top-right
        path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerLength))

        // Bottom-right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerLength))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY))

        // Bottom-left
        path.move(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerLength))

        return path
    }
}

private struct ScanSweepLine: View {
    let side: CGFloat
    @State private var yOffset: CGFloat = 0

    var body: some View {
        let lineHeight = max(side * 0.12, 24)
        let halfTravel = max((side - lineHeight) / 2, 0)
        let gradient = LinearGradient(
            colors: [
                Color.white.opacity(0),
                Color.white.opacity(0.7),
                Color.white.opacity(0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        Rectangle()
            .fill(gradient)
            .frame(height: lineHeight)
            .offset(y: yOffset)
            .onAppear {
                yOffset = -halfTravel
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    yOffset = halfTravel
                }
            }
    }
}
