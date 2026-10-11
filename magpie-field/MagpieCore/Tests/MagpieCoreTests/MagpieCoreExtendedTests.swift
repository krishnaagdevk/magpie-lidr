//
//  MagpieCoreExtendedTests.swift
//  MagpieCoreTests
//
//  Tests for KitchenTag (T-401), KitchenCatalog (T-402), CaptureMetadata (T-403),
//  PackageBuilder (T-606), and SiteCaptureRecord (T-703).
//

import XCTest
@testable import MagpieCore

final class MagpieCoreExtendedTests: XCTestCase {

    // MARK: - T-401 KitchenTag Tests
    func testKitchenTagVocabularyAndTolerances() {
        let tag = KitchenTagItem(
            elementId: "wall-sink-run",
            category: .baseCabinetRun,
            fixed: false,
            notes: "Main kitchen base run"
        )
        XCTAssertEqual(tag.category.displayName, "Base Cabinet Run")
        XCTAssertTrue(tag.category.isCriticalByDefault)
        XCTAssertEqual(tag.category.defaultToleranceMm, 10)
        XCTAssertFalse(tag.fixed)

        let applianceTag = KitchenTagItem(
            elementId: "opening-fridge",
            category: .refrigeratorOpening,
            fixed: true
        )
        XCTAssertEqual(applianceTag.category.defaultToleranceMm, 5)
    }

    func testKitchenTagValidationAgainstPlan() {
        let wall = PlanWall(
            identifier: "wall-1",
            dimensions: Vec3(x: 3.5, y: 2.7, z: 0.15),
            transform: Mat4.identity
        )
        let plan = EditedPlan(walls: [wall])

        let validTag = KitchenTagItem(elementId: "wall-1", category: .baseCabinetRun)
        XCTAssertTrue(validTag.validate(against: plan))

        let orphanTag = KitchenTagItem(elementId: "non-existent-wall", category: .wallCabinetRun)
        XCTAssertFalse(orphanTag.validate(against: plan))
    }

    // MARK: - T-402 KitchenCatalog Tests
    func testKitchenCatalogDefaults() {
        let fridge = KitchenCatalog.item(for: "appliance")
        XCTAssertNotNil(fridge)

        let standardBase = KitchenCatalog.item(for: "cab-base-standard")
        XCTAssertNotNil(standardBase)
        XCTAssertEqual(standardBase?.standardWidthMm, 600)
        XCTAssertEqual(standardBase?.standardDepthMm, 600)
        XCTAssertEqual(standardBase?.standardHeightMm, 870)
        XCTAssertEqual(standardBase?.toleranceMm, 10)
    }

    // MARK: - T-403 CaptureMetadata Tests
    func testCaptureMetadataValidSiteId() throws {
        let meta = try CaptureMetadata(
            siteId: "SITE-2026-KITCHEN-01",
            workerName: "Alex Mercer",
            roomLabel: "Main Kitchen"
        )
        XCTAssertEqual(meta.siteId, "SITE-2026-KITCHEN-01")
        XCTAssertEqual(meta.workerName, "Alex Mercer")
        XCTAssertTrue(meta.capturedAt.contains("T"))
    }

    func testCaptureMetadataRejectsInvalidSiteId() {
        // Empty
        XCTAssertThrowsError(try CaptureMetadata(siteId: "", workerName: "Worker"))
        // Whitespace
        XCTAssertThrowsError(try CaptureMetadata(siteId: "SITE 2026", workerName: "Worker"))
        // Path separators
        XCTAssertThrowsError(try CaptureMetadata(siteId: "SITE/2026", workerName: "Worker"))
        XCTAssertThrowsError(try CaptureMetadata(siteId: "SITE\\2026", workerName: "Worker"))
    }

    // MARK: - T-606 PackageBuilder Tests
    func testPackageBuilderAssembly() throws {
        let wall = PlanWall(
            identifier: "w-01",
            dimensions: Vec3(x: 3.0, y: 2.7, z: 0.15),
            transform: Mat4.translation(x: 1, y: 0, z: 1)
        )
        let plan = EditedPlan(walls: [wall])

        let payload = MeasurementsPayload(
            siteId: "SITE-PKG-01",
            workerName: "Test Engineer",
            capturedAt: "2026-03-30T10:00:00Z",
            deviceModel: "iPhone 15 Pro",
            appVersion: "1.0.0",
            dimensions: [
                Measurement(
                    id: "dim-1",
                    kind: "wall",
                    label: "Wall 1 Length",
                    valueMm: 3000,
                    valueScannedMm: 3000,
                    provenance: .scanned,
                    critical: true,
                    toleranceMm: 10
                )
            ],
            validation: ValidationBlock()
        )

        let pkg = try PackageBuilder.build(plan: plan, measurements: payload, title: "Test Unit")
        XCTAssertTrue(PackageBuilder.validate(package: pkg))
        XCTAssertEqual(pkg.manifest.siteId, "SITE-PKG-01")
        XCTAssertTrue(pkg.manifest.files.contains("manifest.json"))
        XCTAssertTrue(pkg.manifest.files.contains("plan.json"))
        XCTAssertTrue(pkg.manifest.files.contains("measurements.json"))
        XCTAssertTrue(pkg.planJson.contains("openplanHandoffVersion"))
        XCTAssertTrue(pkg.measurementsJson.contains("SITE-PKG-01"))

        let zipData = try PackageBuilder.exportZip(package: pkg)
        XCTAssertGreaterThan(zipData.count, 22)
        XCTAssertEqual(zipData[0], 0x50)
        XCTAssertEqual(zipData[1], 0x4b)
        XCTAssertEqual(zipData[2], 0x03)
        XCTAssertEqual(zipData[3], 0x04)
    }

    // MARK: - T-703 SiteCaptureRecord Tests
    func testSiteCaptureRecordStateTransitions() {
        var record = SiteCaptureRecord(
            siteId: "SITE-STATE-01",
            roomLabel: "Kitchen",
            workerName: "Field Agent"
        )
        XCTAssertEqual(record.syncState, .pending)
        XCTAssertEqual(record.uploadAttempts, 0)

        record.markUploading()
        XCTAssertEqual(record.syncState, .uploading)
        XCTAssertEqual(record.uploadAttempts, 1)

        record.markConfirmed(checksum: "sha256-abcdef123456")
        XCTAssertEqual(record.syncState, .confirmed)
        XCTAssertEqual(record.checksum, "sha256-abcdef123456")
        XCTAssertNil(record.errorMessage)

        record.markFailed(error: "Network timeout")
        XCTAssertEqual(record.syncState, .failed)
        XCTAssertEqual(record.errorMessage, "Network timeout")
    }
}
