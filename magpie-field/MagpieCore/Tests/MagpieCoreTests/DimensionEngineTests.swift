//
//  DimensionEngineTests.swift
//  MagpieCoreTests
//
//  Unit tests for ScanStatistics, Measurement provenance, DimensionEngine,
//  CriticalDimension rules, bias calibration, and MeasurementTableExporter.
//

import XCTest
@testable import MagpieCore

final class DimensionEngineTests: XCTestCase {

    // MARK: - T-201: Millimetre Boundary Conversion & ScanStatistics

    func testMillimetreConversionAndRounding() {
        XCTAssertEqual(ScanStatistics.toMm(3.4565), 3457)
        XCTAssertEqual(ScanStatistics.toMm(3.4564), 3456)
        XCTAssertEqual(ScanStatistics.toMm(0.9144), 914)
        XCTAssertEqual(ScanStatistics.toMm(6.0), 6000)
    }

    func testScanStatisticsFromPlan() {
        var plan = EditedPlan()
        plan.walls = [
            PlanWall(identifier: "w1", dimensions: Vec3(x: 6.0, y: 2.735, z: 0.275), transform: Mat4.translation(x: 3.0, y: 1.3675, z: 0.0), story: 0),
            PlanWall(identifier: "w2", dimensions: Vec3(x: 4.0, y: 2.735, z: 0.275), transform: Mat4.translation(x: 6.0, y: 1.3675, z: 2.0), story: 0)
        ]
        let stats = ScanStatistics.from(plan: plan)
        XCTAssertEqual(stats.wallCount, 2)
        XCTAssertEqual(stats.roomHeightMm, 2735)
        XCTAssertGreaterThan(stats.floorArea, 0)
    }

    // MARK: - T-202: Provenance Model

    func testDerivedProvenanceInheritsWeakestInput() {
        let tapeM = Measurement(
            id: "m1",
            kind: "wall",
            label: "Wall 1",
            valueMm: 3000,
            valueScannedMm: 2990,
            provenance: .tape
        )
        let scannedM = Measurement(
            id: "m2",
            kind: "wall",
            label: "Wall 2",
            valueMm: 2000,
            valueScannedMm: 2000,
            provenance: .scanned
        )

        let derived = Measurement.derive(
            id: "run",
            kind: "run",
            label: "Total Run",
            valueMm: 5000,
            valueScannedMm: 4990,
            inputs: [tapeM, scannedM]
        )

        // Weakest input is scanned, so derived cannot claim tape
        XCTAssertEqual(derived.provenance, .scanned)
    }

    func testTapeRecordingNeverOverwritesScannedValue() {
        var plan = EditedPlan()
        plan.walls = [
            PlanWall(identifier: "w1", dimensions: Vec3(x: 3.505, y: 2.4, z: 0.12), transform: .identity, story: 0)
        ]

        var measurements = DimensionEngine.generateMeasurements(from: plan)
        XCTAssertEqual(measurements.first?.valueMm, 3505)
        XCTAssertEqual(measurements.first?.valueScannedMm, 3505)
        XCTAssertEqual(measurements.first?.provenance, .scanned)

        DimensionEngine.recordTapeMeasurement(
            in: &measurements,
            id: "w1",
            tapeValueMm: 3512,
            note: "Verified with Stanley tape"
        )

        XCTAssertEqual(measurements.first?.valueMm, 3512)
        XCTAssertEqual(measurements.first?.valueScannedMm, 3505) // Intact!
        XCTAssertEqual(measurements.first?.provenance, .tape)
        XCTAssertEqual(measurements.first?.deviationMm, 7)
        XCTAssertEqual(measurements.first?.withinTolerance, true) // 7 <= 10
        XCTAssertEqual(measurements.first?.note, "Verified with Stanley tape")
    }

    // MARK: - T-203 & T-204: DimensionEngine & Critical Dimension Rules

    func testNoTagFallbackProducesNonEmptyCriticalSet() {
        var plan = EditedPlan()
        plan.walls = [
            PlanWall(identifier: "w_short", dimensions: Vec3(x: 2.0, y: 2.4, z: 0.12), transform: .identity, story: 0),
            PlanWall(identifier: "w_long", dimensions: Vec3(x: 5.5, y: 2.4, z: 0.12), transform: .identity, story: 0)
        ]
        plan.sections = [
            PlanSection(center: Vec3(x: 2, y: 0, z: 2), label: "Kitchen", ceilingHeight: 2.74, story: 0)
        ]

        let measurements = DimensionEngine.generateMeasurements(from: plan, tags: [])

        let criticals = measurements.filter { $0.critical }
        XCTAssertFalse(criticals.isEmpty, "No-tag room must yield non-empty critical set")

        // Longest wall must be promoted
        let longestWallM = measurements.first(where: { $0.id == "w_long" })
        XCTAssertEqual(longestWallM?.critical, true)

        // Ceiling must be critical
        let ceilingM = measurements.first(where: { $0.kind == "ceiling" })
        XCTAssertEqual(ceilingM?.critical, true)
    }

    func testKitchenTagsPromoteCabinetRunToCritical() {
        var plan = EditedPlan()
        plan.walls = [
            PlanWall(identifier: "wall-base", dimensions: Vec3(x: 3.2, y: 2.4, z: 0.12), transform: .identity, story: 0),
            PlanWall(identifier: "wall-other", dimensions: Vec3(x: 4.0, y: 2.4, z: 0.12), transform: .identity, story: 0)
        ]

        let tag = KitchenTag(elementId: "wall-base", category: "base-cabinet-run", label: "Base run", fixed: false)
        let measurements = DimensionEngine.generateMeasurements(from: plan, tags: [tag])

        let baseWallM = measurements.first(where: { $0.id == "wall-base" })
        XCTAssertEqual(baseWallM?.critical, true)
    }

    // MARK: - T-205: Bias Calibration

    func testBiasCalibrationAdjustsDimensions() {
        // Scanned 2010 mm against 2000 mm reference => factor = 2000 / 2010 ≈ 0.99502487
        let biasFactor: Float = 2000.0 / 2010.0

        var plan = EditedPlan()
        plan.walls = [
            PlanWall(identifier: "w_3500", dimensions: Vec3(x: 3.5, y: 2.4, z: 0.12), transform: .identity, story: 0)
        ]

        let measurements = DimensionEngine.generateMeasurements(from: plan, biasFactor: biasFactor)
        guard let wallM = measurements.first else {
            XCTFail("Missing wall measurement")
            return
        }

        XCTAssertEqual(wallM.provenance, .calibrated)
        XCTAssertEqual(wallM.valueScannedMm, 3500)
        // 3500 * (2000 / 2010) = 3482.587... rounds to 3483 mm
        XCTAssertEqual(wallM.valueMm, 3483)
    }

    // MARK: - T-502 & T-605: Validation Block & MeasurementTableExporter

    func testValidationPassRateAndGateResult() {
        var measurements: [Measurement] = [
            Measurement(id: "1", kind: "wall", label: "W1", valueMm: 3000, valueScannedMm: 2995, provenance: .tape, critical: true, toleranceMm: 10), // in tol (5 <= 10)
            Measurement(id: "2", kind: "wall", label: "W2", valueMm: 3000, valueScannedMm: 2992, provenance: .tape, critical: true, toleranceMm: 10), // in tol (8 <= 10)
            Measurement(id: "3", kind: "wall", label: "W3", valueMm: 3000, valueScannedMm: 2994, provenance: .tape, critical: true, toleranceMm: 10), // in tol (6 <= 10)
            Measurement(id: "4", kind: "wall", label: "W4", valueMm: 3000, valueScannedMm: 2991, provenance: .tape, critical: true, toleranceMm: 10), // in tol (9 <= 10)
            Measurement(id: "5", kind: "wall", label: "W5", valueMm: 3000, valueScannedMm: 2993, provenance: .tape, critical: true, toleranceMm: 10), // in tol (7 <= 10)
            Measurement(id: "6", kind: "wall", label: "W6", valueMm: 3000, valueScannedMm: 2980, provenance: .tape, critical: true, toleranceMm: 10)  // OUT of tol (20 > 10)
        ]

        let val = DimensionEngine.computeValidation(from: measurements, photosCaptured: 4)
        XCTAssertEqual(val.criticalCount, 6)
        XCTAssertEqual(val.criticalWithinTolerance, 5)
        XCTAssertEqual(val.passRate, 5.0 / 6.0, accuracy: 0.001)
        XCTAssertEqual(val.gateResult, "fail")
        XCTAssertEqual(val.photosCaptured, 4)
    }

    func testMeasurementTableExporterEmitsValidJSON() throws {
        var plan = EditedPlan()
        plan.walls = [
            PlanWall(identifier: "w1", dimensions: Vec3(x: 3.5, y: 2.4, z: 0.12), transform: .identity, story: 0)
        ]
        let dimensions = DimensionEngine.generateMeasurements(from: plan)

        let payload = MeasurementTableExporter.buildPayload(
            siteId: "SITE-2026-0001",
            workerName: "Antigravity",
            capturedAt: "2026-10-10T12:00:00Z",
            deviceModel: "iPhone16,1",
            appVersion: "1.0.0",
            plan: plan,
            dimensions: dimensions,
            photosCaptured: 2
        )

        let data = try MeasurementTableExporter.exportJSONData(payload: payload)
        XCTAssertFalse(data.isEmpty)

        let decoded = try JSONDecoder().decode(MeasurementsPayload.self, from: data)
        XCTAssertEqual(decoded.siteId, "SITE-2026-0001")
        XCTAssertEqual(decoded.dimensions.count, dimensions.count)
        for dim in decoded.dimensions {
            XCTAssertNotNil(dim.provenance)
        }
    }

    func testUntapedCriticalDimensionsFailGate() {
        var plan = EditedPlan()
        plan.walls = [
            PlanWall(identifier: "w1", dimensions: Vec3(x: 4.0, y: 2.4, z: 0.15), transform: .identity, story: 0)
        ]
        let tags = [
            KitchenTag(elementId: "w1", category: "base-cabinet-run", label: "Sink Run", fixed: true)
        ]
        var measurements = DimensionEngine.generateMeasurements(from: plan, tags: tags)
        measurements = CriticalDimensionRules.markCritical(plan: plan, measurements: measurements, tags: tags)

        // Critical dimension is still untaped (provenance .scanned, no note) -> gate must fail
        let val = DimensionEngine.computeValidation(from: measurements, photosCaptured: 2)
        XCTAssertEqual(val.criticalCount, 1)
        XCTAssertEqual(val.criticalWithinTolerance, 0)
        XCTAssertEqual(val.gateResult, "fail")
    }
}
