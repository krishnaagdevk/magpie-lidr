//
//  SiteCaptureRecord.swift
//  MagpieCore
//
//  Capture record representation for local storage, library view, and sync state tracking (Layer 1, T-703).
//

import Foundation

public enum SyncState: String, Codable, CaseIterable, Sendable {
    case pending = "pending"
    case uploading = "uploading"
    case uploaded = "uploaded"
    case confirmed = "confirmed"
    case failed = "failed"
}

public struct SiteCaptureRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var siteId: String
    public var roomLabel: String
    public var capturedAt: String // ISO 8601
    public var workerName: String
    public var syncState: SyncState
    public var checksum: String?
    public var packageSize: Int64
    public var errorMessage: String?
    public var uploadAttempts: Int
    public var lastAttemptAt: String?

    public typealias SyncStatus = SyncState

    public var syncStatus: SyncState {
        get { syncState }
        set { syncState = newValue }
    }

    public var attemptCount: Int {
        get { uploadAttempts }
        set { uploadAttempts = newValue }
    }

    public var packageData: Data?

    public var createdAt: Date {
        ISO8601DateFormatter().date(from: capturedAt) ?? Date()
    }

    public init(
        id: String = UUID().uuidString,
        siteId: String,
        roomLabel: String = "Kitchen",
        capturedAt: String = ISO8601DateFormatter().string(from: Date()),
        workerName: String,
        syncState: SyncState = .pending,
        checksum: String? = nil,
        packageSize: Int64 = 0,
        errorMessage: String? = nil,
        uploadAttempts: Int = 0,
        lastAttemptAt: String? = nil
    ) {
        self.id = id
        self.siteId = siteId
        self.roomLabel = roomLabel
        self.capturedAt = capturedAt
        self.workerName = workerName
        self.syncState = syncState
        self.checksum = checksum
        self.packageSize = packageSize
        self.errorMessage = errorMessage
        self.uploadAttempts = uploadAttempts
        self.lastAttemptAt = lastAttemptAt
        self.packageData = nil
    }

    public init(
        id: String = UUID().uuidString,
        siteId: String,
        workerName: String,
        roomLabel: String = "Kitchen",
        syncStatus: SyncState = .pending,
        packageData: Data? = nil
    ) {
        self.id = id
        self.siteId = siteId
        self.roomLabel = roomLabel
        self.capturedAt = ISO8601DateFormatter().string(from: Date())
        self.workerName = workerName
        self.syncState = syncStatus
        self.checksum = nil
        self.packageSize = Int64(packageData?.count ?? 0)
        self.errorMessage = nil
        self.uploadAttempts = 0
        self.lastAttemptAt = nil
        self.packageData = packageData
    }

    /// State machine transitions
    public mutating func markUploading() {
        self.syncState = .uploading
        self.uploadAttempts += 1
        self.lastAttemptAt = ISO8601DateFormatter().string(from: Date())
    }

    public mutating func markUploaded() {
        self.syncState = .uploaded
        self.errorMessage = nil
    }

    public mutating func markConfirmed(checksum: String) {
        self.syncState = .confirmed
        self.checksum = checksum
        self.errorMessage = nil
    }

    public mutating func markFailed(error: String) {
        self.syncState = .failed
        self.errorMessage = error
    }
}
