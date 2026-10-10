//
//  HandoffExporterV1.swift
//  MagpieCore
//
//  Serializes EditedPlan into iPhone -> Web Handoff v1 JSON (Layer 1).
//  Pure Swift, strictly matching docs/handoff-format-v1.md.
//

import Foundation

public struct HandoffExporterV1 {

    public struct ExportPayload: Codable, Equatable {
        public var openplanPrepared: Bool
        public var openplanHandoffVersion: Int
        public var walls: [ExportWall]
        public var doors: [ExportDoor]
        public var windows: [ExportWindow]
        public var openings: [ExportOpening]
        public var objects: [ExportObject]
        public var sections: [ExportSection]
        public var stories: [ExportStory]
        public var floors: [String]
        public var defaults: ExportDefaults
        public var version: Int
    }

    public struct ExportWall: Codable, Equatable {
        public var identifier: String
        public var dimensions: [Float]
        public var transform: [Float]
        public var category: [String: EmptyObject]
        public var story: Int
    }

    public struct ExportDoor: Codable, Equatable {
        public var identifier: String
        public var parentIdentifier: String
        public var dimensions: [Float]
        public var transform: [Float]
        public var category: [String: EmptyObject]
        public var story: Int
        public var style: String
        public var hingeLeft: Bool
        public var opensInward: Bool
    }

    public struct ExportWindow: Codable, Equatable {
        public var identifier: String
        public var parentIdentifier: String
        public var dimensions: [Float]
        public var transform: [Float]
        public var category: [String: EmptyObject]
        public var story: Int
        public var style: String
        public var sillHeight: Float
    }

    public struct ExportOpening: Codable, Equatable {
        public var identifier: String
        public var parentIdentifier: String
        public var dimensions: [Float]
        public var transform: [Float]
        public var category: [String: EmptyObject]
        public var story: Int
    }

    public struct ExportObject: Codable, Equatable {
        public var identifier: String
        public var dimensions: [Float]
        public var transform: [Float]
        public var category: [String: EmptyObject]
        public var attributes: [String: String]
        public var story: Int
    }

    public struct ExportSection: Codable, Equatable {
        public var center: [Float]
        public var label: String
        public var displayName: String?
        public var color: String?
        public var ceilingHeight: Float?
        public var story: Int
    }

    public struct ExportStory: Codable, Equatable {
        public var index: Int
        public var name: String
    }

    public struct ExportDefaults: Codable, Equatable {
        public var ceilingHeight: Float
        public var interiorWallThickness: Float
        public var exteriorWallThickness: Float
    }

    public struct EmptyObject: Codable, Equatable {
        public init() {}
    }

    /// Converts an EditedPlan into the export payload after running local validation.
    public static func buildPayload(from plan: EditedPlan) throws -> ExportPayload {
        try HandoffValidator.validate(plan: plan)

        let walls = plan.walls.map { wall in
            ExportWall(
                identifier: wall.identifier,
                dimensions: [wall.dimensions.x, wall.dimensions.y, wall.dimensions.z],
                transform: wall.transform.m,
                category: ["wall": EmptyObject()],
                story: wall.story
            )
        }

        let doors = plan.doors.map { door in
            ExportDoor(
                identifier: door.identifier,
                parentIdentifier: door.parentIdentifier,
                dimensions: [door.dimensions.x, door.dimensions.y, door.dimensions.z],
                transform: door.transform.m,
                category: ["door": EmptyObject()],
                story: door.story,
                style: door.style ?? "single",
                hingeLeft: door.hingeLeft ?? true,
                opensInward: door.opensInward ?? false
            )
        }

        let windows = plan.windows.map { win in
            ExportWindow(
                identifier: win.identifier,
                parentIdentifier: win.parentIdentifier,
                dimensions: [win.dimensions.x, win.dimensions.y, win.dimensions.z],
                transform: win.transform.m,
                category: ["window": EmptyObject()],
                story: win.story,
                style: win.style ?? "fixed",
                sillHeight: win.sillHeight ?? 0.0
            )
        }

        let openings = plan.openings.map { op in
            ExportOpening(
                identifier: op.identifier,
                parentIdentifier: op.parentIdentifier,
                dimensions: [op.dimensions.x, op.dimensions.y, op.dimensions.z],
                transform: op.transform.m,
                category: ["opening": EmptyObject()],
                story: op.story
            )
        }

        let objects = plan.objects.map { obj in
            ExportObject(
                identifier: obj.identifier,
                dimensions: [obj.dimensions.x, obj.dimensions.y, obj.dimensions.z],
                transform: obj.transform.m,
                category: [obj.category: EmptyObject()],
                attributes: obj.attributes,
                story: obj.story
            )
        }

        let sections = plan.sections.map { sec in
            ExportSection(
                center: [sec.center.x, sec.center.y, sec.center.z],
                label: sec.label,
                displayName: sec.displayName,
                color: sec.color,
                ceilingHeight: sec.ceilingHeight,
                story: sec.story
            )
        }

        let stories = plan.stories.map { s in
            ExportStory(index: s.index, name: s.name)
        }

        return ExportPayload(
            openplanPrepared: plan.openplanPrepared,
            openplanHandoffVersion: plan.openplanHandoffVersion,
            walls: walls,
            doors: doors,
            windows: windows,
            openings: openings,
            objects: objects,
            sections: sections,
            stories: stories,
            floors: [],
            defaults: ExportDefaults(
                ceilingHeight: 2.4,
                interiorWallThickness: 0.12,
                exteriorWallThickness: 0.2
            ),
            version: 2
        )
    }

    /// Serializes an EditedPlan to JSON Data
    public static func exportJSONData(from plan: EditedPlan) throws -> Data {
        let payload = try buildPayload(from: plan)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        return try encoder.encode(payload)
    }
}
