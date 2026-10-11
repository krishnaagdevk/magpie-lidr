//
//  ScanStatistics.swift
//  MagpieCore
//
//  Room statistics and geometry calculations (Layer 1).
//  Pure Swift, keeping metres internally and converting to millimetres at the boundary.
//

import Foundation

public struct ScanStatistics: Sendable, Codable, Equatable {
    public var wallCount: Int = 0
    public var doorCount: Int = 0
    public var windowCount: Int = 0
    public var objectCount: Int = 0
    public var openingCount: Int = 0
    public var floorArea: Float = 0 // m²

    // Room bounding box dimensions in metres internally
    public var roomWidth: Float = 0   // m
    public var roomHeight: Float = 0  // m
    public var roomDepth: Float = 0   // m

    // Calculated area and volume in metres internally
    public var wallArea: Float = 0    // m²
    public var volume: Float = 0      // m³

    public init(
        wallCount: Int = 0,
        doorCount: Int = 0,
        windowCount: Int = 0,
        objectCount: Int = 0,
        openingCount: Int = 0,
        floorArea: Float = 0,
        roomWidth: Float = 0,
        roomHeight: Float = 0,
        roomDepth: Float = 0,
        wallArea: Float = 0,
        volume: Float = 0
    ) {
        self.wallCount = wallCount
        self.doorCount = doorCount
        self.windowCount = windowCount
        self.objectCount = objectCount
        self.openingCount = openingCount
        self.floorArea = floorArea
        self.roomWidth = roomWidth
        self.roomHeight = roomHeight
        self.roomDepth = roomDepth
        self.wallArea = wallArea
        self.volume = volume
    }

    public var totalElements: Int {
        wallCount + doorCount + windowCount + objectCount + openingCount
    }

    // MARK: - Millimetre Conversions (At Boundary Only)

    /// Converts metres to integer millimetres with proper rounding.
    public static func toMm(_ metres: Float) -> Int {
        return Int((metres * 1000.0).rounded())
    }

    public var roomWidthMm: Int {
        Self.toMm(roomWidth)
    }

    public var roomHeightMm: Int {
        Self.toMm(roomHeight)
    }

    public var roomDepthMm: Int {
        Self.toMm(roomDepth)
    }

    public var summary: String {
        var parts: [String] = []
        if wallCount > 0 { parts.append("\(wallCount) wall\(wallCount == 1 ? "" : "s")") }
        if doorCount > 0 { parts.append("\(doorCount) door\(doorCount == 1 ? "" : "s")") }
        if windowCount > 0 { parts.append("\(windowCount) window\(windowCount == 1 ? "" : "s")") }
        if objectCount > 0 { parts.append("\(objectCount) object\(objectCount == 1 ? "" : "s")") }
        if floorArea > 0 { parts.append(String(format: "%.1f m² floor", floorArea)) }
        return parts.isEmpty ? "No elements detected" : parts.joined(separator: ", ")
    }

    public var detailedSummary: String {
        var lines: [String] = []

        // Millimetre dimensions at the boundary
        if roomWidthMm > 0 && roomDepthMm > 0 {
            lines.append("Dimensions: \(roomWidthMm) × \(roomDepthMm) mm (approx. \(String(format: "%.2f", roomWidth)) × \(String(format: "%.2f", roomDepth)) m)")
        }
        if roomHeightMm > 0 {
            lines.append("Ceiling Height: \(roomHeightMm) mm (\(String(format: "%.2f", roomHeight)) m)")
        }

        // Areas
        if floorArea > 0 {
            lines.append(String(format: "Floor Area: %.2f m² (%.0f sq ft)", floorArea, floorArea * 10.764))
        }
        if wallArea > 0 {
            lines.append(String(format: "Wall Area: %.2f m²", wallArea))
        }
        if volume > 0 {
            lines.append(String(format: "Volume: %.2f m³", volume))
        }

        // Elements
        lines.append("")
        lines.append("Elements: \(wallCount) walls, \(doorCount) doors, \(windowCount) windows")
        if objectCount > 0 {
            lines.append("Furniture: \(objectCount) object\(objectCount == 1 ? "" : "s")")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Factory from EditedPlan

    public static func from(plan: EditedPlan) -> ScanStatistics {
        var stats = ScanStatistics()
        stats.wallCount = plan.walls.count
        stats.doorCount = plan.doors.count
        stats.windowCount = plan.windows.count
        stats.openingCount = plan.openings.count
        stats.objectCount = plan.objects.count

        guard !plan.walls.isEmpty else { return stats }

        var minX: Float = .greatestFiniteMagnitude
        var maxX: Float = -.greatestFiniteMagnitude
        var minY: Float = .greatestFiniteMagnitude
        var maxY: Float = -.greatestFiniteMagnitude
        var minZ: Float = .greatestFiniteMagnitude
        var maxZ: Float = -.greatestFiniteMagnitude
        var totalWallArea: Float = 0

        for wall in plan.walls {
            let halfX = wall.dimensions.x / 2.0
            let halfY = wall.dimensions.y / 2.0
            let halfZ = wall.dimensions.z / 2.0

            let trans = wall.transform.translation

            minX = min(minX, trans.x - halfX)
            maxX = max(maxX, trans.x + halfX)
            minY = min(minY, trans.y - halfY)
            maxY = max(maxY, trans.y + halfY)
            minZ = min(minZ, trans.z - halfZ)
            maxZ = max(maxZ, trans.z + halfZ)

            totalWallArea += wall.dimensions.x * wall.dimensions.y
        }

        stats.roomWidth = max(0, maxX - minX)
        stats.roomHeight = max(0, maxY - minY)
        stats.roomDepth = max(0, maxZ - minZ)
        stats.wallArea = totalWallArea

        // WO-10: Compute floor area via RoomPolygon shoelace formula when closed within tolerance
        let aabbArea = stats.roomWidth * stats.roomDepth
        let segments = RoomPolygon.extractSegments(from: plan)
        let chain = RoomPolygon.orderSegmentsIntoChain(segments)
        var isClosed = false
        if let first = chain.first, let last = chain.last, chain.count >= 3 {
            let gap = last.end.distance(to: first.start)
            isClosed = gap <= RoomPolygon.closureToleranceM
        }

        if isClosed {
            let vertices = chain.map { $0.start }
            stats.floorArea = RoomPolygon.computeShoelaceArea(vertices: vertices)
        } else {
            stats.floorArea = aabbArea
        }
        stats.volume = stats.floorArea * stats.roomHeight

        return stats
    }
}
