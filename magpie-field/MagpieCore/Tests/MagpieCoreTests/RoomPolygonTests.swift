//
//  RoomPolygonTests.swift
//  MagpieCoreTests
//
//  Tests for wall ordering, polygon closure, Shoelace area, and coverage analyzer (T-901, T-904).
//

import XCTest
@testable import MagpieCore

final class RoomPolygonTests: XCTestCase {

    func testShoelaceAreaOnRectangle() {
        // 4m x 3m rectangle -> area should be exactly 12.0 m^2
        let vertices = [
            Pt2(x: 0, y: 0),
            Pt2(x: 4, y: 0),
            Pt2(x: 4, y: 3),
            Pt2(x: 0, y: 3)
        ]
        let area = RoomPolygon.computeShoelaceArea(vertices: vertices)
        XCTAssertEqual(area, 12.0, accuracy: 0.001)
    }

    func testWallOrderingAndClosureOnClosedRectangle() {
        // Define a 4-wall rectangle (4m by 3m)
        // Wall 1: along x axis at y=0, length=4, center=(2, 0)
        let w1 = PlanWall(
            id: "wall-1",
            transform: Mat4.translation(x: 2, y: 0, z: 0),
            dimensions: Vec3(x: 4, y: 2.7, z: 0.15)
        )
        // Wall 2: along z axis at x=4, length=3, center=(4, 1.5), rotated 90 deg
        let w2 = PlanWall(
            id: "wall-2",
            transform: Mat4(elements: [
                0, 0, 1, 0,
                0, 1, 0, 0,
                -1, 0, 0, 0,
                4, 0, 1.5, 1
            ]),
            dimensions: Vec3(x: 3, y: 2.7, z: 0.15)
        )
        // Wall 3: along x axis at z=3, length=4, center=(2, 3), rotated 180 deg
        let w3 = PlanWall(
            id: "wall-3",
            transform: Mat4(elements: [
                -1, 0, 0, 0,
                0, 1, 0, 0,
                0, 0, -1, 0,
                2, 0, 3, 1
            ]),
            dimensions: Vec3(x: 4, y: 2.7, z: 0.15)
        )
        // Wall 4: along z axis at x=0, length=3, center=(0, 1.5), rotated 270 deg
        let w4 = PlanWall(
            id: "wall-4",
            transform: Mat4(elements: [
                0, 0, -1, 0,
                0, 1, 0, 0,
                1, 0, 0, 0,
                0, 0, 1.5, 1
            ]),
            dimensions: Vec3(x: 3, y: 2.7, z: 0.15)
        )

        let plan = EditedPlan(walls: [w1, w2, w3, w4])
        let report = RoomPolygon.analyzeCoverage(for: plan)

        XCTAssertTrue(report.isComplete)
        XCTAssertTrue(report.isClosed)
        XCTAssertEqual(report.wallCount, 4)
        XCTAssertLessThanOrEqual(report.gapMm, 200)
        XCTAssertEqual(report.floorAreaM2, 12.0, accuracy: 0.05)
        XCTAssertEqual(report.summedWallLengthMm, 14000)
        XCTAssertTrue(report.warnings.isEmpty)
    }

    func testOpenRoomDetectsGapAndFlagsIncomplete() {
        // Missing wall 4 (only walls 1, 2, 3)
        let w1 = PlanWall(
            id: "wall-1",
            transform: Mat4.translation(x: 2, y: 0, z: 0),
            dimensions: Vec3(x: 4, y: 2.7, z: 0.15)
        )
        let w2 = PlanWall(
            id: "wall-2",
            transform: Mat4(elements: [
                0, 0, 1, 0,
                0, 1, 0, 0,
                -1, 0, 0, 0,
                4, 0, 1.5, 1
            ]),
            dimensions: Vec3(x: 3, y: 2.7, z: 0.15)
        )
        let w3 = PlanWall(
            id: "wall-3",
            transform: Mat4(elements: [
                -1, 0, 0, 0,
                0, 1, 0, 0,
                0, 0, -1, 0,
                2, 0, 3, 1
            ]),
            dimensions: Vec3(x: 4, y: 2.7, z: 0.15)
        )

        let plan = EditedPlan(walls: [w1, w2, w3])
        let report = RoomPolygon.analyzeCoverage(for: plan)

        XCTAssertFalse(report.isComplete)
        XCTAssertFalse(report.isClosed)
        // Gap between (0, 3) and (0, 0) should be approx 3000 mm
        XCTAssertGreaterThan(report.gapMm, 2000)
        XCTAssertFalse(report.warnings.isEmpty)
    }

    func testInteriorAreaParityWithWebConvention() {
        // 4m x 3m room with 0.20m (20cm) wall thickness
        // Centerline = 12.0 m², interior = (4 - 0.2) * (3 - 0.2) = 3.8 * 2.8 = 10.64 m²
        let vertices = [
            Pt2(x: 0, y: 0),
            Pt2(x: 4, y: 0),
            Pt2(x: 4, y: 3),
            Pt2(x: 0, y: 3)
        ]
        let interior = RoomPolygon.computeInteriorArea(vertices: vertices, wallThicknessM: 0.20)
        XCTAssertEqual(interior, 10.64, accuracy: 0.001)
    }
}
