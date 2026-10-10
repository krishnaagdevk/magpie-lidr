//
//  UsdzExporter.swift
//  MagpieField
//
//  Exports 3D mesh, parametric, and textured USDZ models (Layer 2, T-105).
//

import Foundation
import RoomPlan

public struct UsdzExporter {
    public static func export(
        room: CapturedRoom,
        to destinationUrl: URL,
        format: UsdzExportFormat = .parametric
    ) throws {
        try room.export(to: destinationUrl, exportOptions: format.exportOption)
    }
}
