//
//  CaptureMetadata.swift
//  MagpieCore
//
//  Metadata capturing site identity, provenance, device environment, and worker info (Layer 1, T-403).
//

import Foundation

public enum CaptureMode: String, Codable, Sendable {
    case roomplan = "roomplan"
    case manual = "manual"
    case arworld = "arworld"
}

public enum SiteIdValidationError: Error, Equatable, CustomStringConvertible, Sendable {
    case empty
    case containsWhitespace
    case containsPathSeparators
    case invalidCharacters(String)

    public var description: String {
        switch self {
        case .empty:
            return "Site ID cannot be empty"
        case .containsWhitespace:
            return "Site ID cannot contain whitespace or newlines"
        case .containsPathSeparators:
            return "Site ID cannot contain '/' or '\\' path separators"
        case .invalidCharacters(let chars):
            return "Site ID contains invalid characters: \(chars)"
        }
    }
}

public struct CaptureMetadata: Codable, Equatable, Sendable {
    public var siteId: String
    public var workerName: String
    public var capturedAt: String // ISO 8601 UTC
    public var deviceModel: String
    public var appVersion: String
    public var captureMode: CaptureMode
    public var roomLabel: String
    public var notes: String?

    public init(
        siteId: String,
        workerName: String,
        capturedAt: String = Self.currentIsoTimestamp(),
        deviceModel: String = "iPhone",
        appVersion: String = "1.0.0",
        captureMode: CaptureMode = .roomplan,
        roomLabel: String = "Kitchen",
        notes: String? = nil
    ) throws {
        try Self.validateSiteId(siteId)
        self.siteId = siteId
        self.workerName = workerName
        self.capturedAt = capturedAt
        self.deviceModel = deviceModel
        self.appVersion = appVersion
        self.captureMode = captureMode
        self.roomLabel = roomLabel
        self.notes = notes
    }

    public static func currentIsoTimestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: Date())
    }

    public static func validateSiteId(_ id: String) throws {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw SiteIdValidationError.empty
        }
        if id.contains(where: { $0.isWhitespace }) {
            throw SiteIdValidationError.containsWhitespace
        }
        if id.contains("/") || id.contains("\\") {
            throw SiteIdValidationError.containsPathSeparators
        }
        // Must be filename- and URL-safe: alphanumerics, dashes, underscores, dots
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
        let invalid = id.unicodeScalars.filter { !allowed.contains($0) }
        if !invalid.isEmpty {
            let invalidStr = String(invalid.map { Character($0) })
            throw SiteIdValidationError.invalidCharacters(invalidStr)
        }
    }
}
