//
//  Geometry.swift
//  MagpieCore
//
//  Pure Swift geometry primitives (Layer 1).
//  Zero Apple-framework dependencies (no simd, no CoreGraphics).
//

import Foundation

/// 2D point with Float coordinates
public struct Pt2: Codable, Equatable {
    public var x: Float
    public var y: Float

    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }

    public static let zero = Pt2(x: 0, y: 0)

    public func distance(to other: Pt2) -> Float {
        let dx = other.x - x
        let dy = other.y - y
        return (dx * dx + dy * dy).squareRoot()
    }
}

/// 3D vector with Float coordinates
public struct Vec3: Codable, Equatable {
    public var x: Float
    public var y: Float
    public var z: Float

    public init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let zero = Vec3(x: 0, y: 0, z: 0)

    public func length() -> Float {
        return (x * x + y * y + z * z).squareRoot()
    }
}

/// 4x4 column-major matrix stored as 16 Float values
public struct Mat4: Codable, Equatable {
    /// 16 elements in column-major order
    public var m: [Float]

    public init(elements: [Float]) {
        precondition(elements.count == 16, "Mat4 requires exactly 16 elements")
        self.m = elements
    }

    public static let identity = Mat4(elements: [
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    ])

    // MARK: - Column-major accessors
    // [m0, m1, m2, m3,   <- column 0 (X axis)
    //  m4, m5, m6, m7,   <- column 1 (Y axis / up)
    //  m8, m9, m10, m11, <- column 2 (Z axis)
    //  m12, m13, m14, m15] <- column 3 (translation)

    public var translation: Vec3 {
        return Vec3(x: m[12], y: m[13], z: m[14])
    }

    public var headingRadians: Float {
        // RoomPlan X is column 0, Z is column 0 index 2
        return atan2(m[2], m[0])
    }

    public var headingDegrees: Float {
        return headingRadians * 180.0 / .pi
    }

    public static func translation(x: Float, y: Float, z: Float) -> Mat4 {
        return Mat4(elements: [
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            x, y, z, 1
        ])
    }

    public static func rotationY(radians: Float) -> Mat4 {
        let cosA = cos(radians)
        let sinA = sin(radians)
        return Mat4(elements: [
             cosA, 0, sinA, 0,
             0,    1, 0,    0,
            -sinA, 0, cosA, 0,
             0,    0, 0,    1
        ])
    }
}

extension Mat4: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Float...) {
        if elements.count == 16 {
            self.init(elements: elements)
        } else {
            self = Mat4.identity
        }
    }
}
