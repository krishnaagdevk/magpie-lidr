//
//  CoverageAnalyzer.swift
//  MagpieField
//
//  Live frame analyzer for tracking motion speed, lighting warnings, and wall closure (Layer 2/3, T-901, T-902).
//

import Foundation
import ARKit
import RoomPlan
import MagpieCore

public struct LiveTrackingStatus: Equatable, Sendable {
    public var isMovingTooFast: Bool = false
    public var isLowLight: Bool = false
    public var currentSpeedMps: Float = 0.0
    public var trackingStateText: String = "Normal"
    public var warningMessage: String? = nil
}

@MainActor
public final class CoverageAnalyzer {
    private var previousFrameTransform: simd_float4x4?
    private var previousFrameTimestamp: TimeInterval = 0
    private var excessiveMotionDuration: TimeInterval = 0

    public static let speedThresholdMps: Float = 0.60 // 0.6 m/s threshold per T-902

    public init() {}

    public func reset() {
        previousFrameTransform = nil
        previousFrameTimestamp = 0
        excessiveMotionDuration = 0
    }

    /// Evaluates ARFrame for translation speed and lighting quality
    public func analyzeFrame(_ frame: ARFrame) -> LiveTrackingStatus {
        var status = LiveTrackingStatus()

        // 1. Camera tracking state
        switch frame.camera.trackingState {
        case .normal:
            status.trackingStateText = "Tracking"
        case .notAvailable:
            status.trackingStateText = "Not Available"
            status.warningMessage = "Tracking unavailable. Reposition device."
        case .limited(let reason):
            switch reason {
            case .insufficientFeatures:
                status.isLowLight = true
                status.trackingStateText = "Low Light / Features"
                status.warningMessage = "Too dark or plain wall. Increase lighting."
            case .excessiveMotion:
                status.isMovingTooFast = true
                status.trackingStateText = "Fast Motion"
                status.warningMessage = "Moving too fast. Slow down."
            case .initializing:
                status.trackingStateText = "Initializing"
            case .relocalizing:
                status.trackingStateText = "Relocalizing"
            @unknown default:
                status.trackingStateText = "Limited"
            }
        }

        // 2. Physical translation speed calculation
        let currentTransform = frame.camera.transform
        let currentTimestamp = frame.timestamp

        if let prevTransform = previousFrameTransform, previousFrameTimestamp > 0 {
            let dt = Float(currentTimestamp - previousFrameTimestamp)
            if dt > 0.001 && dt < 0.5 {
                let p1 = simd_make_float3(prevTransform.columns.3)
                let p2 = simd_make_float3(currentTransform.columns.3)
                let distance = simd_distance(p1, p2)
                let speed = distance / dt
                status.currentSpeedMps = speed

                if speed > Self.speedThresholdMps {
                    excessiveMotionDuration += Double(dt)
                    if excessiveMotionDuration > 0.8 { // Sustained for ~1s
                        status.isMovingTooFast = true
                        if status.warningMessage == nil {
                            status.warningMessage = "Slow down — move steadily."
                        }
                    }
                } else {
                    excessiveMotionDuration = max(0, excessiveMotionDuration - Double(dt) * 2.0)
                }
            }
        }

        previousFrameTransform = currentTransform
        previousFrameTimestamp = currentTimestamp

        return status
    }

    /// Evaluates coverage on intermediate CapturedRoom
    public func evaluateRoomCoverage(_ room: CapturedRoom) -> CoverageReport {
        let editedPlan = EditedPlan(capturedRoom: room)
        return RoomPolygon.analyzeCoverage(for: editedPlan)
    }
}
