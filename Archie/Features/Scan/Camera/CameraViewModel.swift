//
//  CameraViewModel.swift
//  Archie
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//


import AVFoundation
import SwiftUI

class CameraViewModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var session = AVCaptureSession()
    @Published var capturedImage: UIImage?
    @Published var previewImage: UIImage?

    private var output = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoOutputQueue = DispatchQueue(label: "com.archie.camera.video-output")
    private var shouldCapturePreviewFrame = false
    private let ciContext = CIContext()

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
        if session.canAddOutput(videoOutput) {
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
            session.addOutput(videoOutput)
            videoOutput.connection(with: .video)?.videoOrientation = .portrait
        }

        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .speed
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        output.capturePhoto(with: settings, delegate: self)
    }

    func requestPreviewFrame() {
        videoOutputQueue.async { [weak self] in
            self?.shouldCapturePreviewFrame = true
        }
        DispatchQueue.main.async { [weak self] in
            self?.previewImage = nil
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let data = photo.fileDataRepresentation() {
            capturedImage = UIImage(data: data)
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard shouldCapturePreviewFrame else { return }
        shouldCapturePreviewFrame = false
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        let image = UIImage(
            cgImage: cgImage,
            scale: 1,
            orientation: imageOrientation(for: connection.videoOrientation)
        )
        DispatchQueue.main.async { [weak self] in
            self?.previewImage = image
        }
    }

    private func imageOrientation(for orientation: AVCaptureVideoOrientation) -> UIImage.Orientation {
        switch orientation {
        case .portrait:
            return .up
        case .portraitUpsideDown:
            return .down
        case .landscapeLeft:
            return .right
        case .landscapeRight:
            return .left
        @unknown default:
            return .up
        }
    }
}
