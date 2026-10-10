//
//  ScaleCalibration.swift
//  MagpieField
//
//  Blueprint image and laser meter scale calibration (Layer 1/2).
//  Maps 2D pixel coordinates to physical metric dimensions in millimetres and metres.
//

import Foundation
import MagpieCore

public struct CalibrationPoint: Codable, Equatable {
    public var x: Float
    public var y: Float

    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }
}

public struct ScaleCalibration {

    /// Calculates millimetres per pixel from two reference points and their real-world distance.
    public static func computeMmPerPixel(
        from pointA: CalibrationPoint,
        to pointB: CalibrationPoint,
        knownDistanceMm: Int
    ) -> Float? {
        guard knownDistanceMm > 0 else { return nil }
        let dx = pointB.x - pointA.x
        let dy = pointB.y - pointA.y
        let pixelDistance = sqrt(dx * dx + dy * dy)
        guard pixelDistance > 1e-4 else { return nil }
        return Float(knownDistanceMm) / pixelDistance
    }

    /// Converts a pixel distance to metres.
    public static func pixelDistanceToMeters(
        pixels: Float,
        mmPerPixel: Float
    ) -> Float {
        return (pixels * mmPerPixel) / 1000.0
    }

    /// Computes rotation angle in degrees from reference line.
    public static func computeHeadingDegrees(
        from pointA: CalibrationPoint,
        to pointB: CalibrationPoint
    ) -> Float {
        let dx = pointB.x - pointA.x
        let dy = pointB.y - pointA.y
        let rad = atan2(dy, dx)
        return rad * 180.0 / .pi
    }
}
