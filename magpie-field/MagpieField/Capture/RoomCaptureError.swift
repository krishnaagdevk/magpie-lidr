//
//  RoomCaptureError.swift
//  MagpieField
//
//  Typed error definitions for room scanning and USDZ variants (Layer 2, T-103).
//

import Foundation
import RoomPlan

public enum RoomCaptureError: LocalizedError, Sendable {
    case noScanData
    case exportFailed(String)
    case sessionFailed(String)
    case processingFailed(String)
    case deviceNotSupported
    case insufficientCoverage(String)

    public var errorDescription: String? {
        switch self {
        case .noScanData:
            return "No room scan data was captured."
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .sessionFailed(let reason):
            return "Capture session failed: \(reason)"
        case .processingFailed(let reason):
            return "Processing failed: \(reason)"
        case .deviceNotSupported:
            return "LiDAR hardware is required for room capture. iPhone Pro or iPad Pro needed."
        case .insufficientCoverage(let msg):
            return "Incomplete wall coverage: \(msg)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .noScanData:
            return "Scan the perimeter of the room slowly before stopping."
        case .exportFailed:
            return "Verify available storage and try exporting again."
        case .sessionFailed:
            return "Ensure the room is adequately lit and restart capture."
        case .processingFailed:
            return "Move more slowly and hold the camera steady."
        case .deviceNotSupported:
            return "Use an iPhone 12 Pro–16 Pro or iPad Pro with LiDAR."
        case .insufficientCoverage:
            return "Rescan missing walls or corners to close the room polygon."
        }
    }
}

public enum UsdzExportFormat: String, CaseIterable, Sendable {
    case parametric
    case model
    case mesh

    public var displayName: String {
        switch self {
        case .parametric: return "Parametric Wireframe"
        case .model: return "Textured Model"
        case .mesh: return "Raw Mesh"
        }
    }

    public var exportOption: CapturedRoom.USDExportOptions {
        switch self {
        case .parametric: return .parametric
        case .model: return .model
        case .mesh: return .mesh
        }
    }
}
