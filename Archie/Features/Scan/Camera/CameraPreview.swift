//
//  CameraPreview.swift
//  Archie
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//


import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
        
        private var lastZoomFactor: CGFloat = 1.0

        override init(frame: CGRect) {
            super.init(frame: frame)
            addPinchGesture()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            addPinchGesture()
        }

        private func addPinchGesture() {
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            self.addGestureRecognizer(pinch)
        }

        @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let device = AVCaptureDevice.default(for: .video) else { return }

            switch gesture.state {
            case .began:
                lastZoomFactor = device.videoZoomFactor
            case .changed:
                let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 6.0)
                let newZoom = min(max(1.0, lastZoomFactor * gesture.scale), maxZoom)
                do {
                    try device.lockForConfiguration()
                    device.videoZoomFactor = newZoom
                    device.unlockForConfiguration()
                } catch {
                    #if DEBUG
                    print("Failed to change zoom: \(error)")
                    #endif
                }
            default:
                break
            }
        }
    }

    let session: AVCaptureSession

    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: VideoPreviewView, context: Context) {}
}
