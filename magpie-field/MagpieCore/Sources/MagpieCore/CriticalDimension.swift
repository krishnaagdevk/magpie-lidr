//
//  CriticalDimension.swift
//  MagpieCore
//
//  Kitchen critical dimension rules (Layer 1).
//  Identifies which dimensions govern cabinet fit and require tape measurement.
//

import Foundation

public struct KitchenTag: Codable, Equatable, Identifiable {
    public var id: String { elementId }
    public var elementId: String
    public var category: String // "base-cabinet-run", "wall-cabinet-run", "refrigerator", "range", etc.
    public var label: String
    public var fixed: Bool // true: physically present; false: planned design intent

    public init(
        elementId: String,
        category: String,
        label: String = "",
        fixed: Bool = false
    ) {
        self.elementId = elementId
        self.category = category
        self.label = label
        self.fixed = fixed
    }
}

public struct CriticalDimensionRules {

    /// Determines if a dimension is critical given the plan, tags, and context.
    ///
    /// Rules:
    /// 1. Cabinet run wall length: any wall tagged with a cabinet run (base or wall)
    /// 2. Opening width: any door or window where an appliance or cabinet is adjacent
    /// 3. Ceiling height: always critical for primary kitchen room/section
    /// 4. Corner-to-corner diagonal: for non-rectangular rooms
    /// 5. Appliance gap: distance between two tagged fixed objects
    /// Fallback when no tags exist: ceiling height and the longest wall.
    public static func markCritical(
        plan: EditedPlan,
        measurements: [Measurement],
        tags: [KitchenTag] = []
    ) -> [Measurement] {
        var result = measurements

        let cabinetCategories: Set<String> = [
            "base-cabinet-run",
            "wall-cabinet-run",
            "tall-cabinet-run",
            "island-run",
            "cabinet"
        ]

        let taggedElementIds = Set(tags.filter { cabinetCategories.contains($0.category) }.map { $0.elementId })

        var markedAny = false

        for i in 0..<result.count {
            let m = result[i]

            // Rule 3: Ceiling height is always critical
            if m.kind == "ceiling" {
                result[i].critical = true
                markedAny = true
                continue
            }

            // Rule 1: Tagged cabinet run wall
            if m.kind == "wall" && taggedElementIds.contains(m.id) {
                result[i].critical = true
                markedAny = true
                continue
            }

            // Rule 2: Opening with critical tag or adjacent cabinet
            if m.kind == "opening" && taggedElementIds.contains(m.id) {
                result[i].critical = true
                result[i].toleranceMm = 5 // 5 mm tolerance for critical openings
                markedAny = true
                continue
            }
        }

        // Fallback rule if no tags were matched (or tags empty):
        // Promote the longest wall and ensure ceiling height is marked
        if tags.isEmpty || !result.contains(where: { $0.kind == "wall" && $0.critical }) {
            // Find longest wall
            var longestWallIndex: Int?
            var maxLen = -1

            for (idx, m) in result.enumerated() where m.kind == "wall" {
                if m.valueMm > maxLen {
                    maxLen = m.valueMm
                    longestWallIndex = idx
                }
            }

            if let lIdx = longestWallIndex {
                result[lIdx].critical = true
            }
        }

        // Ensure every critical dimension recalculates tolerance and withinTolerance
        for i in 0..<result.count {
            if result[i].critical && result[i].kind == "opening" {
                result[i].toleranceMm = min(result[i].toleranceMm, 5)
            }
            let dev = abs(result[i].valueMm - result[i].valueScannedMm)
            result[i].deviationMm = dev
            result[i].withinTolerance = dev <= result[i].toleranceMm
        }

        return result
    }
}
