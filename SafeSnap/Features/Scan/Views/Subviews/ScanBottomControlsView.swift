//
//  ScanBottomControlsView.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 02/08/2025.
//

import SwiftUI

struct ScanBottomControlsView: View {
    let onCapture: () -> Void
    let onGallery: () -> Void

    var body: some View {
        let cameraDiameter: CGFloat = 78

        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack {
                BottomBlurShape(cameraDiameter: cameraDiameter * 1.3)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.15), radius: 16, y: -2)

                HStack {
                    Image("home")
                        .font(.title3)
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 6, y: 2)
                        )

                    Spacer()

                    Button(action: onCapture) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: cameraDiameter, height: cameraDiameter)
                            Circle()
                                .strokeBorder(Color.green, lineWidth: 4)
                                .frame(width: cameraDiameter - 18, height: cameraDiameter - 18)
                        }
                    }
                    .accessibilityLabel("Capture photo")
                    .padding(.bottom, 45)

                    Spacer()

                    Button(action: onGallery) {
                        Image("image")
                            .font(.title3)
                            .frame(width: 48, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.05), radius: 6, y: 2)
                            )
                    }
                    .accessibilityLabel("Choose from Photos")
                }
                .padding(.horizontal, 60)
                .padding(.top, -18)
                .padding(.bottom, max(20, bottomInset + 12))
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .frame(height: 70)
    }
}

/// Custom background silhouette that mirrors the frosted footer from the design.
/// The top edge is a rounded rectangle with an inward “notch” for the capture button.
private struct BottomBlurShape: Shape {
    /// How rounded the outer top corners should be.
    var cornerRadius: CGFloat = 38
    /// Diameter of the camera button; used to align the notch perfectly.
    var cameraDiameter: CGFloat = 98
    /// The notch hugs roughly one third of the button height.
    var notchDepthRatio: CGFloat = 1.0 / 3.0

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Convenience aliases so the math reads closer to a sketch.
        let topY = rect.minY
        let bottomY = rect.maxY
        let leftX = rect.minX
        let rightX = rect.maxX
        let centerX = rect.midX

        // Camera-button geometry.
        let buttonRadius = cameraDiameter / 2
        let notchDepth = min(cameraDiameter * notchDepthRatio, buttonRadius)

        // Given a circle with radius r, the half-width of a chord for a sagitta s is sqrt(r^2 - (r - s)^2).
        let halfNotchFromButton = sqrt(max(buttonRadius * buttonRadius - pow(buttonRadius - notchDepth, 2), 0))

        // Clamp inputs so we never exceed the available width.
        let radius = min(cornerRadius, rect.width / 2)
        let halfNotch = min(halfNotchFromButton, (rect.width / 2) - radius * 0.7)

        // Center of the circular notch so its arc matches the camera button.
        let notchCenterY = topY + (buttonRadius - notchDepth)

        // Start on the left edge, inset by the corner radius to prep the first arc.
        path.move(to: CGPoint(x: leftX, y: topY + radius))

        // Draw the top-left rounded corner.
        path.addQuadCurve(
            to: CGPoint(x: leftX + radius, y: topY),
            control: CGPoint(x: leftX, y: topY)
        )

        // Travel along the top edge until we reach the start of the notch.
        path.addLine(to: CGPoint(x: centerX - halfNotch, y: topY))

        // Carve the notch using an arc so it mirrors the camera button curvature.
        let startAngle = Angle(radians: atan2(topY - notchCenterY, -halfNotch))
        let endAngle = Angle(radians: atan2(topY - notchCenterY, halfNotch))
        path.addArc(
            center: CGPoint(x: centerX, y: notchCenterY),
            radius: buttonRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )

        // Continue toward the right corner.
        path.addLine(to: CGPoint(x: rightX - radius, y: topY))

        // Draw the top-right rounded corner.
        path.addQuadCurve(
            to: CGPoint(x: rightX, y: topY + radius),
            control: CGPoint(x: rightX, y: topY)
        )

        // Close the pill by running down the sides and across the bottom.
        path.addLine(to: CGPoint(x: rightX, y: bottomY))
        path.addLine(to: CGPoint(x: leftX, y: bottomY))
        path.closeSubpath()

        return path
    }
}

#if DEBUG
struct ScanBottomControlsView_Previews: PreviewProvider {
    static var previews: some View {
        ScanBottomControlsView(onCapture: {}, onGallery: {})
            .background(Color(uiColor: .systemGray6))
    }
}
#endif
