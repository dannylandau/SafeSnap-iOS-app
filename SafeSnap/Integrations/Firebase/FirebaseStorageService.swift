//
//  FirebaseStorageService.swift
//  SafeSnap
//
//  Firebase Storage integration for image uploads
//

import Foundation
import FirebaseStorage
import UIKit

// MARK: - Storage Errors

enum StorageServiceError: LocalizedError {
    case imageEncodingFailed
    case uploadFailed(underlying: Error)
    case downloadURLFailed
    case invalidPath
    
    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return "Failed to encode image for upload"
        case .uploadFailed(let error):
            return "Failed to upload image: \(error.localizedDescription)"
        case .downloadURLFailed:
            return "Failed to get download URL"
        case .invalidPath:
            return "Invalid storage path"
        }
    }
}

// MARK: - Storage Service Protocol

protocol ImageStorageService {
    func uploadAnalysisImage(image: UIImage, analysisId: String) async throws -> String
    func deleteAnalysisImage(analysisId: String) async throws
}

// MARK: - Firebase Storage Service

final class FirebaseStorageService: ImageStorageService {
    
    // MARK: - Properties
    
    private let storage: Storage
    private let basePath = "analysis-images/public"
    
    // MARK: - Singleton
    
    static let shared = FirebaseStorageService()
    
    // MARK: - Init
    
    init(storage: Storage = Storage.storage()) {
        self.storage = storage
    }
    
    // MARK: - Public Methods
    
    /// Upload an analysis image to Firebase Storage
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - analysisId: The unique analysis ID to use as filename
    /// - Returns: The download URL string for the uploaded image
    func uploadAnalysisImage(image: UIImage, analysisId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw StorageServiceError.imageEncodingFailed
        }
        
        let path = "\(basePath)/\(analysisId)"
        let storageRef = storage.reference().child(path)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        do {
            _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
            let downloadURL = try await storageRef.downloadURL()
            return downloadURL.absoluteString
        } catch {
            throw StorageServiceError.uploadFailed(underlying: error)
        }
    }
    
    /// Upload image data directly (useful when you already have compressed data)
    /// - Parameters:
    ///   - data: The image data to upload
    ///   - analysisId: The unique analysis ID to use as filename
    ///   - contentType: The MIME type of the image (default: image/jpeg)
    /// - Returns: The download URL string for the uploaded image
    func uploadImageData(_ data: Data, analysisId: String, contentType: String = "image/jpeg") async throws -> String {
        let path = "\(basePath)/\(analysisId)"
        let storageRef = storage.reference().child(path)
        
        let metadata = StorageMetadata()
        metadata.contentType = contentType
        
        do {
            _ = try await storageRef.putDataAsync(data, metadata: metadata)
            let downloadURL = try await storageRef.downloadURL()
            return downloadURL.absoluteString
        } catch {
            throw StorageServiceError.uploadFailed(underlying: error)
        }
    }
    
    /// Delete an analysis image from Firebase Storage
    /// - Parameter analysisId: The analysis ID of the image to delete
    func deleteAnalysisImage(analysisId: String) async throws {
        let path = "\(basePath)/\(analysisId)"
        let storageRef = storage.reference().child(path)
        
        do {
            try await storageRef.delete()
        } catch {
            // Ignore not found errors (image may already be deleted)
            let nsError = error as NSError
            if nsError.domain == StorageErrorDomain && nsError.code == StorageErrorCode.objectNotFound.rawValue {
                return
            }
            throw StorageServiceError.uploadFailed(underlying: error)
        }
    }
    
    /// Get the download URL for an existing analysis image
    /// - Parameter analysisId: The analysis ID of the image
    /// - Returns: The download URL string, or nil if not found
    func getImageURL(analysisId: String) async -> String? {
        let path = "\(basePath)/\(analysisId)"
        let storageRef = storage.reference().child(path)
        
        do {
            let downloadURL = try await storageRef.downloadURL()
            return downloadURL.absoluteString
        } catch {
            return nil
        }
    }
}

// MARK: - Mock Storage Service for Testing

#if DEBUG
final class MockStorageService: ImageStorageService {
    var uploadedImages: [String: UIImage] = [:]
    var shouldFail = false
    var mockURL = "https://firebasestorage.googleapis.com/mock/test-image.jpg"
    
    func uploadAnalysisImage(image: UIImage, analysisId: String) async throws -> String {
        if shouldFail {
            throw StorageServiceError.uploadFailed(underlying: NSError(domain: "MockError", code: -1))
        }
        uploadedImages[analysisId] = image
        return mockURL
    }
    
    func deleteAnalysisImage(analysisId: String) async throws {
        if shouldFail {
            throw StorageServiceError.uploadFailed(underlying: NSError(domain: "MockError", code: -1))
        }
        uploadedImages.removeValue(forKey: analysisId)
    }
}
#endif
