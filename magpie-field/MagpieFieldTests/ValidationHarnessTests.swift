//
//  ValidationHarnessTests.swift
//  MagpieFieldTests
//
//  Phase 9 (T-903): Multi-kitchen validation harness test suite.
//  Tests 5 canonical kitchen geometries across various scan deviations, tolerances, and calibration scenarios.
//

import XCTest
import MagpieCore

final class ValidationHarnessTests: XCTestCase {

    /// Scenario 1: Standard 4m x 3m rectangular kitchen with base and wall cabinet runs.
    func testStandardRectangularKitchen() {
        var plan = EditedPlan()
        plan.walls.append(PlanWall(identifier: "w-north", dimensions: Vec3(x: 4.0, y: 2.4, z: 0.15), transform: [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,1.2,1.5,1]))
        plan.walls.append(PlanWall(identifier: "w-south", dimensions: Vec3(x: 4.0, y: 2.4, z: 0.15), transform: [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,1.2,-1.5,1]))
        plan.walls.append(PlanWall(identifier: "w-east", dimensions: Vec3(x: 3.0, y: 2.4, z: 0.15), transform: [0,0,1,0, 0,1,0,0, -1,0,0,0, 2.0,1.2,0,1]))
        plan.walls.append(PlanWall(identifier: "w-west", dimensions: Vec3(x: 3.0, y: 2.4, z: 0.15), transform: [0,0,1,0, 0,1,0,0, -1,0,0,0, -2.0,1.2,0,1]))

        let tags = [
            KitchenTag(elementId: "w-north", category: "base-cabinet-run", label: "Sink & Cooktop Run", fixed: true),
            KitchenTag(elementId: "w-east", category: "tall-cabinet-run", label: "Pantry & Fridge", fixed: true)
        ]

        var measurements = DimensionEngine.generateMeasurements(from: plan, tags: tags)
        measurements = CriticalDimensionRules.markCritical(plan: plan, measurements: measurements, tags: tags)

        let criticals = measurements.filter { $0.critical }
        XCTAssertEqual(criticals.count, 2, "North and East walls should be promoted to critical due to cabinet tags")

        // Apply tape measurements within ±5mm tolerance
        measurements = DimensionEngine.applyTapeMeasurement(to: measurements, id: "w-north", tapeMm: 4003)
        measurements = DimensionEngine.applyTapeMeasurement(to: measurements, id: "w-east", tapeMm: 2998)

        let validation = DimensionEngine.computeValidation(measurements: measurements, photosCaptured: 4)
        XCTAssertEqual(validation.gateResult, "pass")
        XCTAssertEqual(validation.criticalWithinTolerance, 2)
        XCTAssertEqual(validation.passRate, 1.0)
    }

    /// Scenario 2: L-shaped kitchen with large dimensional deviation exceeding tolerance (Amber/Red band).
    func testLShapedKitchenDeviationFailsGate() {
        var plan = EditedPlan()
        plan.walls.append(PlanWall(identifier: "w-main", dimensions: Vec3(x: 5.0, y: 2.4, z: 0.15), transform: [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,1.2,0,1]))

        let tags = [KitchenTag(elementId: "w-main", category: "base-cabinet-run", label: "Main Run", fixed: true)]
        var measurements = DimensionEngine.generateMeasurements(from: plan, tags: tags)
        measurements = CriticalDimensionRules.markCritical(plan: plan, measurements: measurements, tags: tags)

        // 5000mm scanned, tape reads 5040mm (deviation 40mm exceeds 10mm tolerance)
        measurements = DimensionEngine.applyTapeMeasurement(to: measurements, id: "w-main", tapeMm: 5040, toleranceMm: 10)

        let validation = DimensionEngine.computeValidation(measurements: measurements, photosCaptured: 2)
        XCTAssertEqual(validation.gateResult, "fail")
        XCTAssertEqual(validation.criticalWithinTolerance, 0)
    }

    /// Scenario 3: Systematic scale bias calibration.
    func testSystematicBiasCalibration() {
        var plan = EditedPlan()
        plan.walls.append(PlanWall(identifier: "w1", dimensions: Vec3(x: 3.0, y: 2.4, z: 0.15), transform: [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,1.2,0,1]))
        plan.walls.append(PlanWall(identifier: "w2", dimensions: Vec3(x: 4.0, y: 2.4, z: 0.15), transform: [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,1.2,0,1]))

        var measurements = DimensionEngine.generateMeasurements(from: plan)
        // Tape measures 1.01x larger consistently
        measurements = DimensionEngine.applyTapeMeasurement(to: measurements, id: "w1", tapeMm: 3030)
        measurements = DimensionEngine.applyTapeMeasurement(to: measurements, id: "w2", tapeMm: 4040)

        let bias = DimensionEngine.computeBiasFactor(measurements: measurements)
        XCTAssertNotNil(bias)
        XCTAssertEqual(bias!, 1.01, accuracy: 0.001)

        let calibrated = DimensionEngine.applyCalibration(to: measurements, biasFactor: bias!)
        let unmeasuredWall = calibrated.first(where: { $0.id == "w1" })
        XCTAssertEqual(unmeasuredWall?.provenance, .tape, "Tape measurement must retain tape provenance and value")
    }

    /// Scenario 4: Inaccessible dimension escape record passes validation when justified.
    func testEscapedDimensionValidation() {
        var plan = EditedPlan()
        plan.walls.append(PlanWall(identifier: "w-blocked", dimensions: Vec3(x: 3.5, y: 2.4, z: 0.15), transform: [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,1.2,0,1]))

        let tags = [KitchenTag(elementId: "w-blocked", category: "base-cabinet-run", label: "Blocked wall", fixed: true)]
        var measurements = DimensionEngine.generateMeasurements(from: plan, tags: tags)
        measurements = CriticalDimensionRules.markCritical(plan: plan, measurements: measurements, tags: tags)

        measurements = DimensionEngine.applyTapeMeasurement(
            to: measurements,
            id: "w-blocked",
            tapeMm: nil,
            escapeReason: "Obstructed by integrated commercial refrigeration stack"
        )

        let validation = DimensionEngine.computeValidation(measurements: measurements, photosCaptured: 3)
        XCTAssertEqual(validation.gateResult, "pass", "Documented escape reasons should permit gate clearance")
    }

    /// Scenario 5: Full package export and handoff validation.
    func testFullPackageExportAndValidation() {
        var plan = EditedPlan()
        plan.walls.append(PlanWall(identifier: "w1", dimensions: Vec3(x: 4.0, y: 2.4, z: 0.15), transform: [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,1.2,0,1]))
        let measurements = DimensionEngine.generateMeasurements(from: plan)
        let metadata = CaptureMetadata(siteId: "SITE-101", workerName: "Alex", roomLabel: "Kitchen", scannedAt: "2026-10-10T12:00:00Z")

        let zipData = PackageBuilder.buildPackage(plan: plan, measurements: measurements, metadata: metadata, photos: [:])
        XCTAssertNotNil(zipData)
        XCTAssertGreaterThan(zipData!.count, 50)
    }
}
