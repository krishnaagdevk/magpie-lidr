//
//  PackageBuilder.swift
//  MagpieCore
//
//  Assembles and validates .magpie handoff bundle packages (Layer 1, T-606).
//  Bundles manifest.json, plan.json, roomplan.json, measurements.json, and metadata.
//

import Foundation

public struct PackageManifest: Codable, Equatable, Sendable {
    public var format: String // "openplan3d-project" or "magpie-project"
    public var version: Int
    public var producer: String // "ios" or "web"
    public var title: String
    public var siteId: String
    public var capturedAt: String
    public var files: [String]

    public init(
        format: String = "openplan3d-project",
        version: Int = 1,
        producer: String = "ios",
        title: String,
        siteId: String,
        capturedAt: String,
        files: [String] = ["manifest.json", "plan.json", "measurements.json"]
    ) {
        self.format = format
        self.version = version
        self.producer = producer
        self.title = title
        self.siteId = siteId
        self.capturedAt = capturedAt
        self.files = files
    }
}

public struct MagpiePackage: Codable, Equatable, Sendable {
    public var manifest: PackageManifest
    public var planJson: String
    public var roomplanJson: String?
    public var measurementsJson: String
    public var assetFilenames: [String]

    public init(
        manifest: PackageManifest,
        planJson: String,
        roomplanJson: String? = nil,
        measurementsJson: String,
        assetFilenames: [String] = []
    ) {
        self.manifest = manifest
        self.planJson = planJson
        self.roomplanJson = roomplanJson
        self.measurementsJson = measurementsJson
        self.assetFilenames = assetFilenames
    }
}

public struct PackageBuilder {
    public static func build(
        plan: EditedPlan,
        measurements: MeasurementsPayload,
        title: String = "Kitchen Scan",
        includeRawRoomPlan: Bool = false
    ) throws -> MagpiePackage {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let planData = try HandoffExporterV1.export(plan: plan)
        guard let planString = String(data: planData, encoding: .utf8) else {
            throw NSError(domain: "PackageBuilder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode plan.json"])
        }

        let measurementsData = try MeasurementTableExporter.export(payload: measurements)
        guard let measurementsString = String(data: measurementsData, encoding: .utf8) else {
            throw NSError(domain: "PackageBuilder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode measurements.json"])
        }

        var files = ["manifest.json", "plan.json", "measurements.json"]
        var roomplanString: String? = nil

        if includeRawRoomPlan {
            files.append("roomplan.json")
            roomplanString = planString // If raw roomplan is retained
        }

        let manifest = PackageManifest(
            title: title,
            siteId: measurements.siteId,
            capturedAt: measurements.capturedAt,
            files: files
        )

        return MagpiePackage(
            manifest: manifest,
            planJson: planString,
            roomplanJson: roomplanString,
            measurementsJson: measurementsString
        )
    }

    /// Validates package integrity
    public static func validate(package: MagpiePackage) -> Bool {
        guard package.manifest.version == 1,
              !package.manifest.title.isEmpty,
              !package.manifest.siteId.isEmpty,
              !package.planJson.isEmpty,
              !package.measurementsJson.isEmpty else {
            return false
        }
        return true
    }
}
