//
//  EditedPlan.swift
//  MagpieCore
//
//  The single source of truth for 2D/3D room layout (Layer 1).
//  Pure Swift, Codable, and independent of Apple frameworks.
//

import Foundation

public struct PlanWall: Codable, Equatable, Identifiable {
    public var id: String { identifier }
    public var identifier: String
    /// dimensions: [length (x), height (y), thickness (z)] in metres
    public var dimensions: Vec3
    public var transform: Mat4
    public var story: Int

    public init(
        identifier: String,
        dimensions: Vec3,
        transform: Mat4,
        story: Int = 0
    ) {
        self.identifier = identifier
        self.dimensions = dimensions
        self.transform = transform
        self.story = story
    }

    public init(
        id: String,
        transform: Mat4,
        dimensions: Vec3,
        story: Int = 0
    ) {
        self.identifier = id
        self.dimensions = dimensions
        self.transform = transform
        self.story = story
    }
}

public struct PlanOpening: Codable, Equatable, Identifiable {
    public var id: String { identifier }
    public var identifier: String
    public var parentIdentifier: String
    /// dimensions: [width, height, thickness] in metres
    public var dimensions: Vec3
    public var transform: Mat4
    public var story: Int
    public var kind: String // "door" or "window"
    public var style: String? // door: single/double/sliding/patio; window: fixed/sliding
    public var hingeLeft: Bool?
    public var opensInward: Bool?
    public var sillHeight: Float?

    public init(
        identifier: String,
        parentIdentifier: String,
        dimensions: Vec3,
        transform: Mat4,
        story: Int = 0,
        kind: String = "door",
        style: String? = nil,
        hingeLeft: Bool? = nil,
        opensInward: Bool? = nil,
        sillHeight: Float? = nil
    ) {
        self.identifier = identifier
        self.parentIdentifier = parentIdentifier
        self.dimensions = dimensions
        self.transform = transform
        self.story = story
        self.kind = kind
        self.style = style
        self.hingeLeft = hingeLeft
        self.opensInward = opensInward
        self.sillHeight = sillHeight
    }
}

public struct PlanObject: Codable, Equatable, Identifiable {
    public var id: String { identifier }
    public var identifier: String
    /// dimensions: [width (x), height (y), depth (z)] in metres
    public var dimensions: Vec3
    public var transform: Mat4
    public var story: Int
    public var category: String
    public var attributes: [String: String]

    public init(
        identifier: String,
        dimensions: Vec3,
        transform: Mat4,
        story: Int = 0,
        category: String,
        attributes: [String: String] = [:]
    ) {
        self.identifier = identifier
        self.dimensions = dimensions
        self.transform = transform
        self.story = story
        self.category = category
        self.attributes = attributes
    }
}

public struct PlanSection: Codable, Equatable, Identifiable {
    public var id: String { label }
    public var center: Vec3
    public var label: String
    public var displayName: String?
    public var color: String?
    public var ceilingHeight: Float?
    public var story: Int

    public init(
        center: Vec3,
        label: String,
        displayName: String? = nil,
        color: String? = nil,
        ceilingHeight: Float? = nil,
        story: Int = 0
    ) {
        self.center = center
        self.label = label
        self.displayName = displayName
        self.color = color
        self.ceilingHeight = ceilingHeight
        self.story = story
    }
}

public struct PlanStory: Codable, Equatable {
    public var index: Int
    public var name: String

    public init(index: Int, name: String) {
        self.index = index
        self.name = name
    }
}

public struct ValidationResult: Codable, Equatable, Sendable {
    public var isValid: Bool
    public var errors: [String]
    public var warnings: [String]

    public init(
        isValid: Bool = true,
        errors: [String] = [],
        warnings: [String] = []
    ) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
}

public struct EditedPlan: Codable, Equatable {
    public var openplanPrepared: Bool
    public var openplanHandoffVersion: Int
    public var walls: [PlanWall]
    public var doors: [PlanOpening]
    public var windows: [PlanOpening]
    public var openings: [PlanOpening]
    public var objects: [PlanObject]
    public var sections: [PlanSection]
    public var stories: [PlanStory]
    public var kitchenTags: [KitchenTagItem]

    public var dimensions: [Measurement] {
        DimensionEngine.generateMeasurements(from: self)
    }

    public init(
        openplanPrepared: Bool = true,
        openplanHandoffVersion: Int = 1,
        walls: [PlanWall] = [],
        doors: [PlanOpening] = [],
        windows: [PlanOpening] = [],
        openings: [PlanOpening] = [],
        objects: [PlanObject] = [],
        sections: [PlanSection] = [],
        stories: [PlanStory] = [],
        kitchenTags: [KitchenTagItem] = []
    ) {
        self.openplanPrepared = openplanPrepared
        self.openplanHandoffVersion = openplanHandoffVersion
        self.walls = walls
        self.doors = doors
        self.windows = windows
        self.openings = openings
        self.objects = objects
        self.sections = sections
        self.stories = stories
        self.kitchenTags = kitchenTags
    }

    public mutating func addWall(_ wall: PlanWall) {
        walls.append(wall)
    }

    public mutating func updateWall(id: String, newDimensions: Vec3) {
        if let index = walls.firstIndex(where: { $0.identifier == id }) {
            walls[index].dimensions = newDimensions
        }
    }

    public mutating func deleteWall(id: String) {
        walls.removeAll(where: { $0.identifier == id })
    }

    public mutating func removeObject(id: String) {
        objects.removeAll(where: { $0.identifier == id })
    }
}

// MARK: - Native 2D Plan Exchange Format (handoff-plan.json)

public struct NativePlanDocument: Codable, Equatable {
    public struct Wall: Codable, Equatable {
        public var id: String
        public var start: Pt2
        public var end: Pt2
        public var height: Float
        public var thickness: Float
        public var level: Int

        public init(id: String, start: Pt2, end: Pt2, height: Float, thickness: Float, level: Int = 0) {
            self.id = id
            self.start = start
            self.end = end
            self.height = height
            self.thickness = thickness
            self.level = level
        }
    }

    public struct Opening: Codable, Equatable {
        public var id: String
        public var wallID: String
        public var position: Float
        public var width: Float
        public var height: Float
        public var kind: String
        public var style: String?
        public var hingeLeft: Bool?
        public var opensInward: Bool?
        public var sillHeight: Float?

        public init(
            id: String,
            wallID: String,
            position: Float,
            width: Float,
            height: Float,
            kind: String,
            style: String? = nil,
            hingeLeft: Bool? = nil,
            opensInward: Bool? = nil,
            sillHeight: Float? = nil
        ) {
            self.id = id
            self.wallID = wallID
            self.position = position
            self.width = width
            self.height = height
            self.kind = kind
            self.style = style
            self.hingeLeft = hingeLeft
            self.opensInward = opensInward
            self.sillHeight = sillHeight
        }
    }

    public struct Furniture: Codable, Equatable {
        public var id: String
        public var category: String
        public var center: Pt2
        public var angle: Float
        public var width: Float
        public var depth: Float
        public var height: Float?
        public var level: Int

        public init(
            id: String,
            category: String,
            center: Pt2,
            angle: Float,
            width: Float,
            depth: Float,
            height: Float? = nil,
            level: Int = 0
        ) {
            self.id = id
            self.category = category
            self.center = center
            self.angle = angle
            self.width = width
            self.depth = depth
            self.height = height
            self.level = level
        }
    }

    public struct Room: Codable, Equatable {
        public var id: String
        public var name: String
        public var center: Pt2
        public var colorHex: String?
        public var ceilingHeight: Float?
        public var level: Int

        public init(
            id: String,
            name: String,
            center: Pt2,
            colorHex: String? = nil,
            ceilingHeight: Float? = nil,
            level: Int = 0
        ) {
            self.id = id
            self.name = name
            self.center = center
            self.colorHex = colorHex
            self.ceilingHeight = ceilingHeight
            self.level = level
        }
    }

    public struct Level: Codable, Equatable {
        public var id: String
        public var name: String
        public var index: Int

        public init(id: String, name: String, index: Int) {
            self.id = id
            self.name = name
            self.index = index
        }
    }

    public var walls: [Wall]
    public var openings: [Opening]
    public var furniture: [Furniture]
    public var rooms: [Room]
    public var levels: [Level]

    public init(
        walls: [Wall] = [],
        openings: [Opening] = [],
        furniture: [Furniture] = [],
        rooms: [Room] = [],
        levels: [Level] = []
    ) {
        self.walls = walls
        self.openings = openings
        self.furniture = furniture
        self.rooms = rooms
        self.levels = levels
    }
}

extension EditedPlan {
    /// Constructs an EditedPlan from a 2D native plan document (e.g. handoff-plan.json).
    public init(fromNativePlan native: NativePlanDocument) {
        self.openplanPrepared = true
        self.openplanHandoffVersion = 1

        var wallMap = [String: NativePlanDocument.Wall]()
        var convertedWalls = [PlanWall]()

        for w in native.walls {
            wallMap[w.id] = w
            let dx = w.end.x - w.start.x
            let dy = w.end.y - w.start.y
            let length = (dx * dx + dy * dy).squareRoot()
            let angle = atan2(dy, dx)
            let cosA = cos(angle)
            let sinA = sin(angle)
            let midX = (w.start.x + w.end.x) / 2.0
            let midY = (w.start.y + w.end.y) / 2.0
            let midZ = w.height / 2.0

            let transform = Mat4(elements: [
                cosA, 0.0, sinA, 0.0,
                0.0, 1.0, 0.0, 0.0,
                -sinA, 0.0, cosA, 0.0,
                midX, midZ, midY, 1.0
            ])

            let planWall = PlanWall(
                identifier: w.id,
                dimensions: Vec3(x: length, y: w.height, z: w.thickness),
                transform: transform,
                story: w.level
            )
            convertedWalls.append(planWall)
        }
        self.walls = convertedWalls

        var convertedDoors = [PlanOpening]()
        var convertedWindows = [PlanOpening]()
        var convertedOpenings = [PlanOpening]()

        for op in native.openings {
            guard let parentWall = wallMap[op.wallID] else { continue }
            let dx = parentWall.end.x - parentWall.start.x
            let dy = parentWall.end.y - parentWall.start.y
            let angle = atan2(dy, dx)
            let cosA = cos(angle)
            let sinA = sin(angle)

            let posX = parentWall.start.x + op.position * dx
            let posY = parentWall.start.y + op.position * dy

            let elevation: Float
            if op.kind == "window" {
                elevation = (op.sillHeight ?? 0.0) + op.height / 2.0
            } else {
                elevation = op.height / 2.0
            }

            let transform = Mat4(elements: [
                cosA, 0.0, sinA, 0.0,
                0.0, 1.0, 0.0, 0.0,
                -sinA, 0.0, cosA, 0.0,
                posX, elevation, posY, 1.0
            ])

            let planOpening = PlanOpening(
                identifier: op.id,
                parentIdentifier: op.wallID,
                dimensions: Vec3(x: op.width, y: op.height, z: parentWall.thickness),
                transform: transform,
                story: parentWall.level,
                kind: op.kind,
                style: op.style,
                hingeLeft: op.hingeLeft,
                opensInward: op.opensInward,
                sillHeight: op.sillHeight
            )

            if op.kind == "door" {
                convertedDoors.append(planOpening)
            } else if op.kind == "window" {
                convertedWindows.append(planOpening)
            } else {
                convertedOpenings.append(planOpening)
            }
        }
        self.doors = convertedDoors
        self.windows = convertedWindows
        self.openings = convertedOpenings

        var convertedObjects = [PlanObject]()
        for f in native.furniture {
            let cosA = cos(f.angle)
            let sinA = sin(f.angle)
            let height = f.height ?? (f.category == "chair" ? 0.9 : 0.8)
            let elevation = height / 2.0

            let transform = Mat4(elements: [
                cosA, 0.0, sinA, 0.0,
                0.0, 1.0, 0.0, 0.0,
                -sinA, 0.0, cosA, 0.0,
                f.center.x, elevation, f.center.y, 1.0
            ])

            let planObj = PlanObject(
                identifier: f.id,
                dimensions: Vec3(x: f.width, y: height, z: f.depth),
                transform: transform,
                story: f.level,
                category: f.category,
                attributes: [:]
            )
            convertedObjects.append(planObj)
        }
        self.objects = convertedObjects

        self.sections = native.rooms.map { r in
            PlanSection(
                center: Vec3(x: r.center.x, y: 0, z: r.center.y),
                label: r.name,
                displayName: r.name,
                color: r.colorHex,
                ceilingHeight: r.ceilingHeight,
                story: r.level
            )
        }

        self.stories = native.levels.map { l in
            PlanStory(index: l.index, name: l.name)
        }
    }
}
