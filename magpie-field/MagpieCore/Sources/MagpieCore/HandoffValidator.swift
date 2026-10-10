//
//  HandoffValidator.swift
//  MagpieCore
//
//  Swift mirror of openPlan3D's roomplanValidation.ts (Layer 1).
//  Validates handoff v1 payload before export.
//

import Foundation

public struct ValidationError: Error, CustomStringConvertible, Equatable {
    public let message: String
    public init(_ message: String) {
        self.message = message
    }
    public var description: String { message }
}

public struct HandoffValidator {
    public static func validate(plan: EditedPlan) throws {
        if plan.openplanHandoffVersion != 1 {
            throw ValidationError("openplanHandoffVersion must equal 1")
        }

        var seenIdentifiers = Set<String>()
        var wallStories = [String: Int]()

        // Validate walls
        for wall in plan.walls {
            let id = wall.identifier.trimmingCharacters(in: .whitespaces)
            if id.isEmpty {
                throw ValidationError("Wall identifier must be non-empty")
            }
            if seenIdentifiers.contains(id) {
                throw ValidationError("Duplicate identifier '\(id)' found in walls")
            }
            seenIdentifiers.insert(id)
            wallStories[id] = wall.story

            if wall.dimensions.x <= 0 || wall.dimensions.y <= 0 || wall.dimensions.z < 0 {
                throw ValidationError("Wall '\(id)' dimensions must have length > 0, height > 0, thickness >= 0")
            }
            try validateTransform(wall.transform, for: id)
        }

        // Validate doors
        for door in plan.doors {
            let id = door.identifier.trimmingCharacters(in: .whitespaces)
            if id.isEmpty {
                throw ValidationError("Door identifier must be non-empty")
            }
            if seenIdentifiers.contains(id) {
                throw ValidationError("Duplicate identifier '\(id)' found across elements")
            }
            seenIdentifiers.insert(id)

            guard let parentStory = wallStories[door.parentIdentifier] else {
                throw ValidationError("Door '\(id)' parentIdentifier '\(door.parentIdentifier)' does not resolve to a wall")
            }
            if parentStory != door.story {
                throw ValidationError("Door '\(id)' must be on the same story as its parent wall (door=\(door.story), wall=\(parentStory))")
            }

            if door.dimensions.x <= 0 || door.dimensions.y <= 0 {
                throw ValidationError("Door '\(id)' dimensions must be positive")
            }
            if let style = door.style, !["single", "double", "sliding", "patio"].contains(style) {
                throw ValidationError("Door '\(id)' invalid style '\(style)'")
            }
            try validateTransform(door.transform, for: id)
        }

        // Validate windows
        for win in plan.windows {
            let id = win.identifier.trimmingCharacters(in: .whitespaces)
            if id.isEmpty {
                throw ValidationError("Window identifier must be non-empty")
            }
            if seenIdentifiers.contains(id) {
                throw ValidationError("Duplicate identifier '\(id)' found across elements")
            }
            seenIdentifiers.insert(id)

            guard let parentStory = wallStories[win.parentIdentifier] else {
                throw ValidationError("Window '\(id)' parentIdentifier '\(win.parentIdentifier)' does not resolve to a wall")
            }
            if parentStory != win.story {
                throw ValidationError("Window '\(id)' must be on the same story as its parent wall")
            }

            if win.dimensions.x <= 0 || win.dimensions.y <= 0 {
                throw ValidationError("Window '\(id)' dimensions must be positive")
            }
            if let sill = win.sillHeight, sill < 0 {
                throw ValidationError("Window '\(id)' sillHeight must be non-negative")
            }
            if let style = win.style, !["fixed", "sliding"].contains(style) {
                throw ValidationError("Window '\(id)' invalid style '\(style)'")
            }
            try validateTransform(win.transform, for: id)
        }

        // Validate objects
        for obj in plan.objects {
            let id = obj.identifier.trimmingCharacters(in: .whitespaces)
            if id.isEmpty {
                throw ValidationError("Object identifier must be non-empty")
            }
            if seenIdentifiers.contains(id) {
                throw ValidationError("Duplicate identifier '\(id)' found across elements")
            }
            seenIdentifiers.insert(id)

            if obj.dimensions.x <= 0 || obj.dimensions.y <= 0 || obj.dimensions.z <= 0 {
                throw ValidationError("Object '\(id)' dimensions must all be strictly positive (> 0)")
            }
            try validateTransform(obj.transform, for: id)
        }

        // Validate stories
        var storyIndices = Set<Int>()
        for story in plan.stories {
            if storyIndices.contains(story.index) {
                throw ValidationError("Duplicate story index \(story.index)")
            }
            storyIndices.insert(story.index)
        }
    }

    private static func validateTransform(_ transform: Mat4, for id: String) throws {
        if transform.m.count != 16 {
            throw ValidationError("Transform for '\(id)' must have exactly 16 elements")
        }
        for (i, val) in transform.m.enumerated() {
            if val.isNaN || val.isInfinite {
                throw ValidationError("Transform for '\(id)' at index \(i) is not finite")
            }
        }
        let t0 = transform.m[0]
        let t2 = transform.m[2]
        let h = (t0 * t0 + t2 * t2).squareRoot()
        if h < 1e-8 {
            throw ValidationError("Transform for '\(id)' horizontal hypot is below 1e-8")
        }
    }
}
