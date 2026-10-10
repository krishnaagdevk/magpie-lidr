//
//  KitchenTag.swift
//  MagpieCore
//
//  Standardized kitchen tag vocabulary and validation (Layer 1, T-401).
//  Promotes cabinet runs, appliance openings, and obstacles to governing critical dimensions.
//

import Foundation

public enum KitchenTagCategory: String, Codable, CaseIterable, Sendable {
    case baseCabinetRun = "base-cabinet-run"
    case wallCabinetRun = "wall-cabinet-run"
    case tallCabinetRun = "tall-cabinet-run"
    case islandRun = "island-run"
    case refrigeratorOpening = "refrigerator-opening"
    case rangeOpening = "range-opening"
    case dishwasherSlot = "dishwasher-slot"
    case sinkBaseRun = "sink-base-run"
    case columnObstruction = "column-obstruction"
    case generalCabinet = "cabinet"

    public var displayName: String {
        switch self {
        case .baseCabinetRun: return "Base Cabinet Run"
        case .wallCabinetRun: return "Wall Cabinet Run"
        case .tallCabinetRun: return "Tall Pantry Run"
        case .islandRun: return "Island Perimeter"
        case .refrigeratorOpening: return "Refrigerator Clearance"
        case .rangeOpening: return "Range/Cooktop Clearance"
        case .dishwasherSlot: return "Dishwasher Opening"
        case .sinkBaseRun: return "Sink Base Unit"
        case .columnObstruction: return "Architectural Obstruction"
        case .generalCabinet: return "Custom Cabinet Run"
        }
    }

    public var isCriticalByDefault: Bool {
        switch self {
        case .baseCabinetRun, .wallCabinetRun, .tallCabinetRun, .refrigeratorOpening, .rangeOpening, .dishwasherSlot:
            return true
        default:
            return false
        }
    }

    public var defaultToleranceMm: Int {
        switch self {
        case .refrigeratorOpening, .rangeOpening, .dishwasherSlot:
            return 5 // Tight appliance opening tolerance
        case .baseCabinetRun, .wallCabinetRun, .tallCabinetRun, .islandRun, .sinkBaseRun:
            return 10 // Wall run tolerance
        default:
            return 15
        }
    }
}

public struct KitchenTagItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String { elementId }
    public var elementId: String
    public var category: KitchenTagCategory
    public var label: String
    public var fixed: Bool // true: physical obstacle/existing fixture; false: planned
    public var notes: String

    public init(
        elementId: String,
        category: KitchenTagCategory,
        label: String = "",
        fixed: Bool = true,
        notes: String = ""
    ) {
        self.elementId = elementId
        self.category = category
        self.label = label.isEmpty ? category.displayName : label
        self.fixed = fixed
        self.notes = notes
    }

    /// Validates that the tagged element actually exists in the plan.
    public func validate(against plan: EditedPlan) -> Bool {
        let existsInWalls = plan.walls.contains(where: { $0.id == elementId })
        let existsInDoors = plan.doors.contains(where: { $0.id == elementId })
        let existsInWindows = plan.windows.contains(where: { $0.id == elementId })
        let existsInOpenings = plan.openings.contains(where: { $0.id == elementId })
        let existsInObjects = plan.objects.contains(where: { $0.id == elementId })
        return existsInWalls || existsInDoors || existsInWindows || existsInOpenings || existsInObjects
    }
}
