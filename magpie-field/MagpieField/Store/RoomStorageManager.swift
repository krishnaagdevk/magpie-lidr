//
//  RoomStorageManager.swift
//  MagpieField
//
//  Manages saving and loading of captured sites, handoff v1 bundles, and local library (Layer 2, T-701).
//  Clean of all WiFi/IFC dependencies.
//

import Foundation
import RoomPlan
import MagpieCore

@MainActor
public final class RoomStorageManager: ObservableObject {
    public static let shared = RoomStorageManager()

    @Published public var savedCaptures: [SiteCapture] = []

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var baseStorageDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("MagpieSites", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            try? StorageEncryption.secureDirectory(at: dir)
        }
        return dir
    }

    private init() {
        self.encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
        loadIndex()
    }

    public func saveCapture(
        siteId: String,
        roomLabel: String,
        workerName: String,
        rawRoom: CapturedRoom?,
        editedPlan: EditedPlan,
        measurements: MeasurementsPayload,
        photoManager: PhotoCaptureManager?
    ) throws -> SiteCapture {
        let captureId = UUID().uuidString
        let siteDir = baseStorageDirectory.appendingPathComponent(captureId, isDirectory: true)
        try fileManager.createDirectory(at: siteDir, withIntermediateDirectories: true)

        // 1. Save Edited Plan (plan.json)
        let planData = try HandoffExporterV1.export(plan: editedPlan)
        let planUrl = siteDir.appendingPathComponent("plan.json")
        try planData.write(to: planUrl)
        try StorageEncryption.applyCompleteProtection(to: planUrl)

        // 2. Save Measurements (measurements.json)
        let measurementsData = try MeasurementTableExporter.export(payload: measurements)
        let measurementsUrl = siteDir.appendingPathComponent("measurements.json")
        try measurementsData.write(to: measurementsUrl)
        try StorageEncryption.applyCompleteProtection(to: measurementsUrl)

        // 3. Save Raw CapturedRoom if present (room.json and model.usdz)
        if let room = rawRoom {
            let usdzUrl = siteDir.appendingPathComponent("model.usdz")
            try? UsdzExporter.export(room: room, to: usdzUrl, format: .parametric)

            let roomJsonUrl = siteDir.appendingPathComponent("room.json")
            try? planData.write(to: roomJsonUrl) // raw export
        }

        // 4. Copy photos
        if let photoManager = photoManager, photoManager.photoCount > 0 {
            _ = try? photoManager.copyPhotos(to: siteDir)
        }

        // 5. Package Manifest (manifest.json)
        let manifest = PackageManifest(
            title: "\(siteId) - \(roomLabel)",
            siteId: siteId,
            capturedAt: measurements.capturedAt,
            files: ["manifest.json", "plan.json", "measurements.json", "model.usdz"]
        )
        let manifestData = try encoder.encode(manifest)
        let manifestUrl = siteDir.appendingPathComponent("manifest.json")
        try manifestData.write(to: manifestUrl)

        // 6. Compute package size
        var totalSize: Int64 = 0
        if let enumerator = fileManager.enumerator(at: siteDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileUrl as URL in enumerator {
                if let size = try? fileUrl.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }

        let capture = SiteCapture(
            id: captureId,
            siteId: siteId,
            roomLabel: roomLabel,
            workerName: workerName,
            capturedAt: measurements.capturedAt,
            localDirectoryUrl: siteDir.path,
            syncState: .pending,
            packageSizeBytes: totalSize,
            criticalCount: measurements.validation.criticalCount,
            passRate: measurements.validation.passRate,
            gateResult: measurements.validation.gateResult
        )

        savedCaptures.insert(capture, at: 0)
        saveIndex()
        return capture
    }

    public func deleteCapture(id: String) {
        if let index = savedCaptures.firstIndex(where: { $0.id == id }) {
            let capture = savedCaptures[index]
            let dirUrl = URL(fileURLWithPath: capture.localDirectoryUrl)
            try? fileManager.removeItem(at: dirUrl)
            savedCaptures.remove(at: index)
            saveIndex()
        }
    }

    private func saveIndex() {
        let indexUrl = baseStorageDirectory.appendingPathComponent("library_index.json")
        if let data = try? encoder.encode(savedCaptures) {
            try? data.write(to: indexUrl)
        }
    }

    private func loadIndex() {
        let indexUrl = baseStorageDirectory.appendingPathComponent("library_index.json")
        guard fileManager.fileExists(atPath: indexUrl.path),
              let data = try? Data(contentsOf: indexUrl),
              let list = try? decoder.decode([SiteCapture].self, from: data) else {
            return
        }
        self.savedCaptures = list
    }
}
