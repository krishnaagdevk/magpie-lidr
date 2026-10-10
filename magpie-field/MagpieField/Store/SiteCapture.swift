//
//  SiteCapture.swift
//  MagpieField
//
//  Local site capture record and metadata model for library listing (Layer 2, T-703).
//

import Foundation
import MagpieCore

public struct SiteCapture: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var siteId: String
    public var roomLabel: String
    public var workerName: String
    public var capturedAt: String
    public var localDirectoryUrl: String
    public var syncState: SyncState
    public var checksum: String?
    public var packageSizeBytes: Int64
    public var criticalCount: Int
    public var passRate: Float
    public var gateResult: String // "pass" | "fail"

    public init(
        id: String = UUID().uuidString,
        siteId: String,
        roomLabel: String = "Main Kitchen",
        workerName: String,
        capturedAt: String = CaptureMetadata.currentIsoTimestamp(),
        localDirectoryUrl: String,
        syncState: SyncState = .pending,
        checksum: String? = nil,
        packageSizeBytes: Int64 = 0,
        criticalCount: Int = 0,
        passRate: Float = 1.0,
        gateResult: String = "pass"
    ) {
        self.id = id
        self.siteId = siteId
        self.roomLabel = roomLabel
        self.workerName = workerName
        self.capturedAt = capturedAt
        self.localDirectoryUrl = localDirectoryUrl
        self.syncState = syncState
        self.checksum = checksum
        self.packageSizeBytes = packageSizeBytes
        self.criticalCount = criticalCount
        self.passRate = passRate
        self.gateResult = gateResult
    }
}
