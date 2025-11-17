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

    var body: some View {
        let widthBound = availableSize.width * 0.78
        let heightBound = availableSize.height * 0.58
        let square = max(min(widthBound, heightBound), 220)

        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .frame(width: square, height: square)

            ScanCornersOverlay()
                .stroke(Color.white.opacity(0.95), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: square, height: square)

            if mode == .scanning {
                ScanSweepLine()
                    .frame(width: square - 30, height: square - 30)
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
    @State private var yOffset: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
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
                .frame(height: 80)
                .cornerRadius(16)
                .offset(y: yOffset)
                .onAppear {
                    yOffset = -height / 2
                    withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                        yOffset = height / 2
                    }
                }
        }
    }
}
