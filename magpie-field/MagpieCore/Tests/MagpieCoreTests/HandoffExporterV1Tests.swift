//
//  HandoffExporterV1Tests.swift
//  MagpieCoreTests
//
//  The fixture round-trip test (T-603).
//  Asserts that EditedPlan exported via HandoffExporterV1 strictly matches handoff-roomplan.json.
//

import XCTest
@testable import MagpieCore

final class HandoffExporterV1Tests: XCTestCase {

    func testFixtureRoundTrip() throws {
        // Locate fixtures
        let planURL = Bundle.module.url(forResource: "handoff-plan", withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: "handoff-plan", withExtension: "json")
        let roomplanURL = Bundle.module.url(forResource: "handoff-roomplan", withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: "handoff-roomplan", withExtension: "json")

        guard let pURL = planURL, let rURL = roomplanURL else {
            XCTFail("Missing handoff fixtures in test bundle")
            return
        }

        let planData = try Data(contentsOf: pURL)
        let roomplanData = try Data(contentsOf: rURL)

        let decoder = JSONDecoder()
        let nativePlan = try decoder.decode(NativePlanDocument.self, from: planData)
        let expectedPayload = try decoder.decode(HandoffExporterV1.ExportPayload.self, from: roomplanData)

        let editedPlan = EditedPlan(fromNativePlan: nativePlan)
        let actualPayload = try HandoffExporterV1.buildPayload(from: editedPlan)

        // 1. Root flags & version
        XCTAssertEqual(actualPayload.openplanPrepared, expectedPayload.openplanPrepared)
        XCTAssertEqual(actualPayload.openplanHandoffVersion, expectedPayload.openplanHandoffVersion)
        XCTAssertEqual(actualPayload.version, expectedPayload.version)
        XCTAssertEqual(actualPayload.floors, expectedPayload.floors)
        XCTAssertEqual(actualPayload.defaults, expectedPayload.defaults)

        // 2. Walls
        XCTAssertEqual(actualPayload.walls.count, expectedPayload.walls.count)
        for (actual, expected) in zip(actualPayload.walls, expectedPayload.walls) {
            XCTAssertEqual(actual.identifier, expected.identifier)
            XCTAssertEqual(actual.story, expected.story)
            XCTAssertEqual(actual.dimensions.count, expected.dimensions.count)
            for (ad, ed) in zip(actual.dimensions, expected.dimensions) {
                XCTAssertEqual(ad, ed, accuracy: 1e-4)
            }
            XCTAssertEqual(actual.transform.count, 16)
            for (at, et) in zip(actual.transform, expected.transform) {
                XCTAssertEqual(at, et, accuracy: 1e-4)
            }
        }

        // 3. Doors
        XCTAssertEqual(actualPayload.doors.count, expectedPayload.doors.count)
        for (actual, expected) in zip(actualPayload.doors, expectedPayload.doors) {
            XCTAssertEqual(actual.identifier, expected.identifier)
            XCTAssertEqual(actual.parentIdentifier, expected.parentIdentifier)
            XCTAssertEqual(actual.story, expected.story)
            XCTAssertEqual(actual.style, expected.style)
            XCTAssertEqual(actual.hingeLeft, expected.hingeLeft)
            XCTAssertEqual(actual.opensInward, expected.opensInward)
            for (ad, ed) in zip(actual.dimensions, expected.dimensions) {
                XCTAssertEqual(ad, ed, accuracy: 1e-4)
            }
            for (at, et) in zip(actual.transform, expected.transform) {
                XCTAssertEqual(at, et, accuracy: 1e-4)
            }
        }

        // 4. Windows
        XCTAssertEqual(actualPayload.windows.count, expectedPayload.windows.count)
        for (actual, expected) in zip(actualPayload.windows, expectedPayload.windows) {
            XCTAssertEqual(actual.identifier, expected.identifier)
            XCTAssertEqual(actual.parentIdentifier, expected.parentIdentifier)
            XCTAssertEqual(actual.story, expected.story)
            XCTAssertEqual(actual.style, expected.style)
            XCTAssertEqual(actual.sillHeight, expected.sillHeight, accuracy: 1e-4)
            for (ad, ed) in zip(actual.dimensions, expected.dimensions) {
                XCTAssertEqual(ad, ed, accuracy: 1e-4)
            }
            for (at, et) in zip(actual.transform, expected.transform) {
                XCTAssertEqual(at, et, accuracy: 1e-4)
            }
        }

        // 5. Openings
        XCTAssertEqual(actualPayload.openings.count, expectedPayload.openings.count)

        // 6. Objects
        XCTAssertEqual(actualPayload.objects.count, expectedPayload.objects.count)
        for (actual, expected) in zip(actualPayload.objects, expectedPayload.objects) {
            XCTAssertEqual(actual.identifier, expected.identifier)
            XCTAssertEqual(actual.story, expected.story)
            for (ad, ed) in zip(actual.dimensions, expected.dimensions) {
                XCTAssertEqual(ad, ed, accuracy: 1e-4)
            }
            for (at, et) in zip(actual.transform, expected.transform) {
                XCTAssertEqual(at, et, accuracy: 1e-4)
            }
        }

        // 7. Sections
        XCTAssertEqual(actualPayload.sections.count, expectedPayload.sections.count)
        for (actual, expected) in zip(actualPayload.sections, expectedPayload.sections) {
            XCTAssertEqual(actual.label, expected.label)
            XCTAssertEqual(actual.displayName, expected.displayName)
            XCTAssertEqual(actual.color, expected.color)
            if let ac = actual.ceilingHeight, let ec = expected.ceilingHeight {
                XCTAssertEqual(ac, ec, accuracy: 1e-4)
            }
            XCTAssertEqual(actual.story, expected.story)
        }

        // 8. Stories
        XCTAssertEqual(actualPayload.stories.count, expectedPayload.stories.count)
        for (actual, expected) in zip(actualPayload.stories, expectedPayload.stories) {
            XCTAssertEqual(actual.index, expected.index)
            XCTAssertEqual(actual.name, expected.name)
        }
    }

    func testValidationRejectsDuplicateIdentifiers() {
        var plan = EditedPlan()
        plan.walls = [
            PlanWall(identifier: "w1", dimensions: Vec3(x: 3, y: 2.5, z: 0.15), transform: .identity, story: 0),
            PlanWall(identifier: "w1", dimensions: Vec3(x: 4, y: 2.5, z: 0.15), transform: .identity, story: 0)
        ]
        XCTAssertThrowsError(try HandoffValidator.validate(plan: plan)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Duplicate identifier"))
        }
    }

    func testValidationRejectsMismatchedStoryParent() {
        var plan = EditedPlan()
        plan.walls = [
            PlanWall(identifier: "w1", dimensions: Vec3(x: 3, y: 2.5, z: 0.15), transform: .identity, story: 0)
        ]
        plan.doors = [
            PlanOpening(identifier: "d1", parentIdentifier: "w1", dimensions: Vec3(x: 0.9, y: 2.0, z: 0.15), transform: .identity, story: 1)
        ]
        XCTAssertThrowsError(try HandoffValidator.validate(plan: plan)) { error in
            XCTAssertTrue(error.localizedDescription.contains("same story"))
        }
    }

    func testValidationRejectsNonPositiveDimensions() {
        var plan = EditedPlan()
        plan.walls = [
            PlanWall(identifier: "w1", dimensions: Vec3(x: -1, y: 2.5, z: 0.15), transform: .identity, story: 0)
        ]
        XCTAssertThrowsError(try HandoffValidator.validate(plan: plan))
    }

    func testEditedPlanCodableRoundTrip() throws {
        var plan = EditedPlan()
        plan.walls = [
            PlanWall(identifier: "w1", dimensions: Vec3(x: 4, y: 2.4, z: 0.12), transform: .identity, story: 0)
        ]
        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(EditedPlan.self, from: data)
        XCTAssertEqual(plan, decoded)
    }
}
