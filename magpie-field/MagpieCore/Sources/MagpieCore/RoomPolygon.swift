//
//  RoomPolygon.swift
//  MagpieCore
//
//  Wall ordering, polygon closure verification, perimeter coverage, and floor area calculation (Layer 1, T-901).
//  Zero Apple-framework dependencies (no simd, no CoreGraphics).
//

import Foundation

public struct WallSegment: Equatable, Sendable {
    public var id: String
    public var start: Pt2
    public var end: Pt2
    public var length: Float

    public init(id: String, start: Pt2, end: Pt2) {
        self.id = id
        self.start = start
        self.end = end
        self.length = start.distance(to: end)
    }

    public func reversed() -> WallSegment {
        WallSegment(id: id, start: end, end: start)
    }
}

public struct CoverageReport: Codable, Equatable, Sendable {
    public var isComplete: Bool
    public var wallCount: Int
    public var isClosed: Bool
    public var gapMm: Int
    public var gapLocationX: Float?
    public var gapLocationY: Float?
    public var floorAreaM2: Float
    public var floorAreaMm2: Int
    public var summedWallLengthMm: Int
    public var perimeterMm: Int
    public var shortfallPercent: Float
    public var warnings: [String]

    public init(
        isComplete: Bool,
        wallCount: Int,
        isClosed: Bool,
        gapMm: Int,
        gapLocationX: Float? = nil,
        gapLocationY: Float? = nil,
        floorAreaM2: Float,
        floorAreaMm2: Int,
        summedWallLengthMm: Int,
        perimeterMm: Int,
        shortfallPercent: Float,
        warnings: [String] = []
    ) {
        self.isComplete = isComplete
        self.wallCount = wallCount
        self.isClosed = isClosed
        self.gapMm = gapMm
        self.gapLocationX = gapLocationX
        self.gapLocationY = gapLocationY
        self.floorAreaM2 = floorAreaM2
        self.floorAreaMm2 = floorAreaMm2
        self.summedWallLengthMm = summedWallLengthMm
        self.perimeterMm = perimeterMm
        self.shortfallPercent = shortfallPercent
        self.warnings = warnings
    }
}

public struct RoomPolygon {
    public static let closureToleranceM: Float = 0.200 // 200 mm threshold per IMPLEMENTATION_PLAN §8.2C

    /// Converts an EditedPlan's walls into 2D ground-plane line segments (metres)
    public static func extractSegments(from plan: EditedPlan) -> [WallSegment] {
        return plan.walls.map { wall in
            let cx = wall.transform.m[12]
            let cy = wall.transform.m[14] // RoomPlan ground plane is X-Z
            let heading = wall.transform.headingRadians
            let halfLen = wall.dimensions.x / 2.0

            let dx = cos(heading) * halfLen
            let dy = sin(heading) * halfLen

            let p1 = Pt2(x: cx - dx, y: cy - dy)
            let p2 = Pt2(x: cx + dx, y: cy + dy)
            return WallSegment(id: wall.id, start: p1, end: p2)
        }
    }

    /// Orders walls into a continuous chain by matching endpoints within tolerance
    public static func orderSegmentsIntoChain(_ segments: [WallSegment], tolerance: Float = closureToleranceM) -> [WallSegment] {
        guard !segments.isEmpty else { return [] }

        var remaining = segments
        var chain: [WallSegment] = [remaining.removeFirst()]

        while !remaining.isEmpty {
            let currentEnd = chain.last!.end
            var bestIndex: Int? = nil
            var bestDistance: Float = Float.greatestFiniteMagnitude
            var shouldFlip = false

            for (index, candidate) in remaining.enumerated() {
                let distToStart = currentEnd.distance(to: candidate.start)
                let distToEnd = currentEnd.distance(to: candidate.end)

                if distToStart < bestDistance {
                    bestDistance = distToStart
                    bestIndex = index
                    shouldFlip = false
                }
                if distToEnd < bestDistance {
                    bestDistance = distToEnd
                    bestIndex = index
                    shouldFlip = true
                }
            }

            guard let index = bestIndex, bestDistance <= tolerance else {
                // Cannot chain further within tolerance; append remaining as-is
                chain.append(contentsOf: remaining)
                break
            }

            let nextSegment = shouldFlip ? remaining[index].reversed() : remaining[index]
            remaining.remove(at: index)
            chain.append(nextSegment)
        }

        return chain
    }

    /// Computes area of a 2D polygon using the Shoelace formula (metres squared)
    public static func computeShoelaceArea(vertices: [Pt2]) -> Float {
        guard vertices.count >= 3 else { return 0.0 }
        var sum: Float = 0.0
        let count = vertices.count

        for i in 0..<count {
            let next = (i + 1) % count
            sum += (vertices[i].x * vertices[next].y) - (vertices[next].x * vertices[i].y)
        }
        return abs(sum) * 0.5
    }

    /// Computes interior room area given centerline vertices and wall thickness (metres).
    /// Parity with web interiorRoomArea convention (4m x 3m with 20cm thickness = 10.64 m²).
    /// Offsets each centerline vertex inward by t/2 along the angle bisector (miter) and shoelaces the offset polygon.
    public static func computeInteriorArea(vertices: [Pt2], wallThicknessM: Float) -> Float {
        let n = vertices.count
        guard n >= 3, wallThicknessM >= 0 else { return 0.0 }

        let centerlineArea = computeShoelaceArea(vertices: vertices)
        guard centerlineArea > 0.0 else { return 0.0 }

        // Determine polygon orientation via signed shoelace area
        var signedArea: Float = 0.0
        for i in 0..<n {
            let next = (i + 1) % n
            signedArea += (vertices[i].x * vertices[next].y) - (vertices[next].x * vertices[i].y)
        }
        signedArea *= 0.5
        guard abs(signedArea) > 0.0001 else { return 0.0 }
        let isCCW = signedArea > 0.0

        let d = wallThicknessM / 2.0

        // Inward unit normals for each edge
        var edgeNormals = [Pt2]()
        edgeNormals.reserveCapacity(n)
        for i in 0..<n {
            let next = (i + 1) % n
            let dx = vertices[next].x - vertices[i].x
            let dy = vertices[next].y - vertices[i].y
            let len = (dx * dx + dy * dy).squareRoot()
            if len <= 0.00001 {
                edgeNormals.append(Pt2.zero)
                continue
            }
            let ux = dx / len
            let uy = dy / len
            // Inward normal: if CCW, rotate +90° (-uy, ux); if CW, rotate -90° (uy, -ux)
            let nx = isCCW ? -uy : uy
            let ny = isCCW ? ux : -ux
            edgeNormals.append(Pt2(x: nx, y: ny))
        }

        // Offset vertices along angle bisector (miter)
        var offsetVertices = [Pt2]()
        offsetVertices.reserveCapacity(n)
        for i in 0..<n {
            let prev = (i - 1 + n) % n
            let nPrev = edgeNormals[prev]
            let nCurr = edgeNormals[i]

            let dot = nPrev.x * nCurr.x + nPrev.y * nCurr.y
            let denom = 1.0 + dot

            var mx: Float
            var my: Float
            if denom > 0.05 {
                mx = d * (nPrev.x + nCurr.x) / denom
                my = d * (nPrev.y + nCurr.y) / denom
            } else {
                mx = d * nCurr.x
                my = d * nCurr.y
            }

            // Clamp miter length to prevent self-intersections or extreme spikes
            let miterLen = (mx * mx + my * my).squareRoot()
            let maxMiter = 2.0 * wallThicknessM
            if miterLen > maxMiter && miterLen > 0.0001 {
                let scale = maxMiter / miterLen
                mx *= scale
                my *= scale
            }

            offsetVertices.append(Pt2(x: vertices[i].x + mx, y: vertices[i].y + my))
        }

        let interiorArea = computeShoelaceArea(vertices: offsetVertices)
        return min(max(0.0, interiorArea), centerlineArea)
    }

    /// Analyzes the walls of a plan for closure, perimeter coverage, and floor area
    public static func analyzeCoverage(for plan: EditedPlan) -> CoverageReport {
        let segments = extractSegments(from: plan)
        let wallCount = segments.count
        var warnings: [String] = []

        if wallCount < 3 {
            warnings.append("Insufficient wall count (\(wallCount) < 3)")
        }

        let chain = orderSegmentsIntoChain(segments)
        let summedWallLengthM: Float = segments.reduce(0.0) { $0 + $1.length }
        let summedWallLengthMm = Int(round(summedWallLengthM * 1000.0))

        var isClosed = false
        var gapDistanceM: Float = 0.0
        var gapLocation: Pt2? = nil

        if let first = chain.first, let last = chain.last {
            gapDistanceM = last.end.distance(to: first.start)
            gapLocation = Pt2(x: (last.end.x + first.start.x) / 2.0, y: (last.end.y + first.start.y) / 2.0)
            isClosed = gapDistanceM <= closureToleranceM
        }

        let gapMm = Int(round(gapDistanceM * 1000.0))
        if !isClosed && wallCount >= 3 {
            warnings.append("Room polygon is open: gap of \(gapMm) mm between endpoints")
        }

        // Polygon vertices formed by the chain
        let vertices = chain.map { $0.start }
        let areaM2 = computeShoelaceArea(vertices: vertices)
        let areaMm2 = Int(round(areaM2 * 1_000_000.0))

        if areaM2 < 1.0 {
            warnings.append("Derived floor area is less than 1.0 m² (\(String(format: "%.2f", areaM2)) m²)")
        }

        // Compute perimeter from vertices
        var perimeterM: Float = 0.0
        if vertices.count >= 3 {
            for i in 0..<vertices.count {
                let next = (i + 1) % vertices.count
                perimeterM += vertices[i].distance(to: vertices[next])
            }
        } else {
            perimeterM = summedWallLengthM
        }
        let perimeterMm = Int(round(perimeterM * 1000.0))

        // Check coverage shortfall
        let shortfallM = max(0.0, perimeterM - summedWallLengthM)
        let shortfallPercent = perimeterM > 0.0 ? (shortfallM / perimeterM) * 100.0 : 0.0
        if shortfallPercent > 15.0 {
            warnings.append(String(format: "Coverage shortfall of %.1f%% exceeds 15%% threshold (missed wall detected)", shortfallPercent))
        }

        let isComplete = isClosed && (wallCount >= 3) && (areaM2 >= 1.0) && (shortfallPercent <= 15.0)

        return CoverageReport(
            isComplete: isComplete,
            wallCount: wallCount,
            isClosed: isClosed,
            gapMm: gapMm,
            gapLocationX: gapLocation?.x,
            gapLocationY: gapLocation?.y,
            floorAreaM2: areaM2,
            floorAreaMm2: areaMm2,
            summedWallLengthMm: summedWallLengthMm,
            perimeterMm: perimeterMm,
            shortfallPercent: shortfallPercent,
            warnings: warnings
        )
    }
}
