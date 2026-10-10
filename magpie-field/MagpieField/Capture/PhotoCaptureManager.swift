//
//  PhotoCaptureManager.swift
//  MagpieField
//
//  Manages capturing and storing reference photographs for kitchen sites (Layer 2, T-104).
//

import UIKit

public final class PhotoCaptureManager: NSObject, @unchecked Sendable {
    public struct CapturedPhoto: Codable, Sendable, Identifiable {
        public let id: UUID
        public let timestamp: Date
        public let fileName: String

        public var formattedTime: String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: timestamp)
        }
    }

    private var capturedPhotos: [CapturedPhoto] = []
    private let lock = NSLock()

    public func addPhoto(_ image: UIImage) -> CapturedPhoto? {
        let id = UUID()
        let fileName = "\(id.uuidString).jpg"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        do {
            try data.write(to: tempURL)
            let photo = CapturedPhoto(id: id, timestamp: Date(), fileName: fileName)
            lock.lock()
            capturedPhotos.append(photo)
            lock.unlock()
            return photo
        } catch {
            print("Failed to save reference photo: \(error)")
            return nil
        }
    }

    public var photos: [CapturedPhoto] {
        lock.lock()
        defer { lock.unlock() }
        return capturedPhotos
    }

    public var photoCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return capturedPhotos.count
    }

    public func clearPhotos() {
        lock.lock()
        let oldPhotos = capturedPhotos
        capturedPhotos.removeAll()
        lock.unlock()

        for photo in oldPhotos {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(photo.fileName)
            try? FileManager.default.removeItem(at: tempURL)
        }
    }

    public func copyPhotos(to directory: URL) throws -> [CapturedPhoto] {
        lock.lock()
        let photos = capturedPhotos
        lock.unlock()

        let photosDir = directory.appendingPathComponent("photos")
        try FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)

        for photo in photos {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(photo.fileName)
            let destURL = photosDir.appendingPathComponent(photo.fileName)
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try? FileManager.default.copyItem(at: tempURL, to: destURL)
            }
        }
        return photos
    }
}
