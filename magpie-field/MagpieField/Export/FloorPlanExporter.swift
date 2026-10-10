//
//  FloorPlanExporter.swift
//  MagpieField
//
//  Exports 2D vector plans as standard SVG and DXF files (Layer 2, T-607).
//

import Foundation
import MagpieCore

public enum VectorExportFormat: String, CaseIterable, Sendable {
    case svg
    case dxf

    public var fileExtension: String { rawValue }
    public var mimeType: String {
        switch self {
        case .svg: return "image/svg+xml"
        case .dxf: return "application/dxf"
        }
    }
}

public struct FloorPlanExporter {
    public static func exportSVG(plan: EditedPlan) -> String {
        let segments = RoomPolygon.extractSegments(from: plan)
        var minX: Float = 0, maxX: Float = 0, minY: Float = 0, maxY: Float = 0

        for s in segments {
            minX = min(minX, min(s.start.x, s.end.x))
            maxX = max(maxX, max(s.start.x, s.end.x))
            minY = min(minY, min(s.start.y, s.end.y))
            maxY = max(maxY, max(s.start.y, s.end.y))
        }

        let margin: Float = 0.5
        let width = max(1.0, (maxX - minX) + margin * 2)
        let height = max(1.0, (maxY - minY) + margin * 2)

        var svg = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="\(minX - margin) \(minY - margin) \(width) \(height)" width="800" height="600">
          <style>
            .wall { stroke: #2c3e50; stroke-width: 0.15; stroke-linecap: round; }
            .door { stroke: #e67e22; stroke-width: 0.10; stroke-dasharray: 0.05,0.05; }
            .dim { font-family: monospace; font-size: 0.12px; fill: #7f8c8d; text-anchor: middle; }
          </style>
        """

        for s in segments {
            svg += "\n  <line x1=\"\(s.start.x)\" y1=\"\(s.start.y)\" x2=\"\(s.end.x)\" y2=\"\(s.end.y)\" class=\"wall\" />"
        }

        svg += "\n</svg>"
        return svg
    }

    public static func exportDXF(plan: EditedPlan) -> String {
        let segments = RoomPolygon.extractSegments(from: plan)
        var dxf = """
        0
        SECTION
        2
        ENTITIES
        """

        for s in segments {
            dxf += """
            \n0
            LINE
            8
            WALLS
            10
            \(s.start.x)
            20
            \(s.start.y)
            30
            0.0
            11
            \(s.end.x)
            21
            \(s.end.y)
            31
            0.0
            """
        }

        dxf += """
        \n0
        ENDSEC
        0
        EOF
        """
        return dxf
    }
}
