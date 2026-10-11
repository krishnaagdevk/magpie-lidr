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

public struct PackageAsset: Codable, Equatable, Sendable {
    public var path: String
    public var data: Data

    public init(path: String, data: Data) {
        self.path = path
        self.data = data
    }
}

public struct MagpiePackage: Codable, Equatable, Sendable {
    public var manifest: PackageManifest
    public var planJson: String
    public var roomplanJson: String?
    public var measurementsJson: String
    public var assets: [PackageAsset]

    public var assetFilenames: [String] {
        assets.map(\.path)
    }

    public init(
        manifest: PackageManifest,
        planJson: String,
        roomplanJson: String? = nil,
        measurementsJson: String,
        assets: [PackageAsset] = []
    ) {
        self.manifest = manifest
        self.planJson = planJson
        self.roomplanJson = roomplanJson
        self.measurementsJson = measurementsJson
        self.assets = assets
    }

    public init(
        manifest: PackageManifest,
        planJson: String,
        roomplanJson: String? = nil,
        measurementsJson: String,
        assetFilenames: [String]
    ) {
        self.manifest = manifest
        self.planJson = planJson
        self.roomplanJson = roomplanJson
        self.measurementsJson = measurementsJson
        self.assets = assetFilenames.map { PackageAsset(path: $0, data: Data()) }
    }
}

public struct PackageBuilder {
    public static func build(
        plan: EditedPlan,
        measurements: MeasurementsPayload,
        title: String = "Kitchen Scan",
        includeRawRoomPlan: Bool = false,
        assets: [PackageAsset] = []
    ) throws -> MagpiePackage {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let planData = try HandoffExporterV1.exportJSONData(from: plan)
        guard let planString = String(data: planData, encoding: .utf8) else {
            throw NSError(domain: "PackageBuilder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode plan.json"])
        }

        let measurementsData = try MeasurementTableExporter.exportJSONData(payload: measurements)
        guard let measurementsString = String(data: measurementsData, encoding: .utf8) else {
            throw NSError(domain: "PackageBuilder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode measurements.json"])
        }

        var files = ["manifest.json", "plan.json", "measurements.json"]
        var roomplanString: String? = nil

        if includeRawRoomPlan {
            files.append("roomplan.json")
            roomplanString = planString
        }

        for asset in assets {
            if !files.contains(asset.path) {
                files.append(asset.path)
            }
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
            measurementsJson: measurementsString,
            assets: assets
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

    /// Exports a MagpiePackage as an uncompressed (Store method 0) ZIP archive
    public static func exportZip(package: MagpiePackage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestData = try encoder.encode(package.manifest)
        let planData = Data(package.planJson.utf8)
        let measurementsData = Data(package.measurementsJson.utf8)

        var entries: [(String, Data)] = [
            ("manifest.json", manifestData),
            ("plan.json", planData),
            ("measurements.json", measurementsData)
        ]

        if let roomplan = package.roomplanJson {
            entries.append(("roomplan.json", Data(roomplan.utf8)))
        }

        for asset in package.assets {
            if !entries.contains(where: { $0.0 == asset.path }) {
                entries.append((asset.path, asset.data))
            }
        }

        return createZipArchive(entries: entries)
    }

    public static func createZipArchive(entries: [(String, Data)]) -> Data {
        var zipData = Data()
        var centralDirectory = Data()
        var centralRecords: [(name: String, offset: UInt32, size: UInt32, crc: UInt32)] = []

        for (name, fileData) in entries {
            let offset = UInt32(zipData.count)
            let nameBytes = Array(name.utf8)
            let size = UInt32(fileData.count)
            let crc = CRC32.checksum(data: fileData)

            centralRecords.append((name, offset, size, crc))

            // Local file header (30 bytes + name + data)
            var localHeader = Data()
            localHeader.appendUInt32LE(0x04034b50) // signature
            localHeader.appendUInt16LE(20)         // version needed (2.0)
            localHeader.appendUInt16LE(0x0800)     // flag (UTF-8)
            localHeader.appendUInt16LE(0)          // compression method (0 = stored)
            localHeader.appendUInt16LE(0)          // mod time
            localHeader.appendUInt16LE(0)          // mod date
            localHeader.appendUInt32LE(crc)        // crc-32
            localHeader.appendUInt32LE(size)       // compressed size
            localHeader.appendUInt32LE(size)       // uncompressed size
            localHeader.appendUInt16LE(UInt16(nameBytes.count)) // file name length
            localHeader.appendUInt16LE(0)          // extra field length
            localHeader.append(contentsOf: nameBytes)
            localHeader.append(fileData)

            zipData.append(localHeader)
        }

        let centralDirOffset = UInt32(zipData.count)

        // Central directory file headers
        for record in centralRecords {
            let nameBytes = Array(record.name.utf8)
            var cdHeader = Data()
            cdHeader.appendUInt32LE(0x02014b50)    // signature
            cdHeader.appendUInt16LE(20)            // version made by
            cdHeader.appendUInt16LE(20)            // version needed
            cdHeader.appendUInt16LE(0x0800)        // flag (UTF-8)
            cdHeader.appendUInt16LE(0)             // compression method (0 = stored)
            cdHeader.appendUInt16LE(0)             // mod time
            cdHeader.appendUInt16LE(0)             // mod date
            cdHeader.appendUInt32LE(record.crc)    // crc-32
            cdHeader.appendUInt32LE(record.size)   // compressed size
            cdHeader.appendUInt32LE(record.size)   // uncompressed size
            cdHeader.appendUInt16LE(UInt16(nameBytes.count)) // file name length
            cdHeader.appendUInt16LE(0)             // extra field length
            cdHeader.appendUInt16LE(0)             // file comment length
            cdHeader.appendUInt16LE(0)             // disk number start
            cdHeader.appendUInt16LE(0)             // internal attributes
            cdHeader.appendUInt32LE(0)             // external attributes
            cdHeader.appendUInt32LE(record.offset) // relative offset of local header
            cdHeader.append(contentsOf: nameBytes)

            centralDirectory.append(cdHeader)
        }

        let centralDirSize = UInt32(centralDirectory.count)
        zipData.append(centralDirectory)

        // End of central directory record (22 bytes)
        var eocd = Data()
        eocd.appendUInt32LE(0x06054b50)            // signature
        eocd.appendUInt16LE(0)                     // disk number
        eocd.appendUInt16LE(0)                     // disk where cd starts
        eocd.appendUInt16LE(UInt16(entries.count)) // records on this disk
        eocd.appendUInt16LE(UInt16(entries.count)) // total records
        eocd.appendUInt32LE(centralDirSize)        // cd size
        eocd.appendUInt32LE(centralDirOffset)      // cd offset
        eocd.appendUInt16LE(0)                     // comment length

        zipData.append(eocd)
        return zipData
    }
}

private struct CRC32 {
    static let table: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                if (c & 1) != 0 {
                    c = 0xedb88320 ^ (c >> 1)
                } else {
                    c = c >> 1
                }
            }
            return c
        }
    }()

    static func checksum(data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xff)
            crc = table[index] ^ (crc >> 8)
        }
        return crc ^ 0xffffffff
    }
}

private extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }
}
