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
    var isCaptureDisabled: Bool = false
    var isGalleryDisabled: Bool = false

    var body: some View {
        let cameraDiameter: CGFloat = 78

        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack {
                Image("union")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height + bottomInset + 40)
//                    .clipped()
                    .shadow(color: Color.black.opacity(0.15), radius: 16, y: -2)
                    .padding(.top, -100)

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
                                .strokeBorder(Color.black.opacity(0.6), lineWidth: 6)
                                .frame(width: cameraDiameter - 6, height: cameraDiameter - 6)
                            Circle()
                                .fill(Color(.black.opacity(0.25)))
                                .frame(width: cameraDiameter - 26, height: cameraDiameter - 26)
                            
                        }
                    }
                    .accessibilityLabel("Capture photo")
                    .disabled(isCaptureDisabled)
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
                    .disabled(isGalleryDisabled)
                }
                .padding(.horizontal, 60)
                .padding(.top, -5)
                .padding(.bottom, max(20, bottomInset + 6))
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .frame(height: 70)
    }
}

#if DEBUG
struct ScanBottomControlsView_Previews: PreviewProvider {
    static var previews: some View {
        ScanBottomControlsView(onCapture: {}, onGallery: {})
            .background(.clear)
    }
}
#endif
