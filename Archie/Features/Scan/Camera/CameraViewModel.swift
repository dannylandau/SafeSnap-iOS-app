//
//  CameraViewModel.swift
//  Archie
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//


import AVFoundation
import SwiftUI

class CameraViewModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var session = AVCaptureSession()
    @Published var capturedImage: UIImage?

    private var output = AVCapturePhotoOutput()

    init(startSession: Bool = true) {
        super.init()
        if startSession {
            setupSession()
        }
    }

    func setupSession() {
        session.beginConfiguration()
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            #if DEBUG
            print("❌ Camera input setup failed")
            #endif
            return
        }

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) { session.addOutput(output) }

        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        output.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let data = photo.fileDataRepresentation() {
            capturedImage = UIImage(data: data)
        }
    }
}
