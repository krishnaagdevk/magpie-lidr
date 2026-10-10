//
//  KitchenCatalog.swift
//  MagpieCore
//
//  Standardized kitchen object catalog, dimensional defaults, and fit envelopes (Layer 1, T-402).
//

import Foundation

public struct KitchenCatalogItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var category: String
    public var name: String
    public var standardWidthMm: Int
    public var standardDepthMm: Int
    public var standardHeightMm: Int
    public var minClearanceMm: Int
    public var toleranceMm: Int

    public init(
        id: String,
        category: String,
        name: String,
        standardWidthMm: Int,
        standardDepthMm: Int,
        standardHeightMm: Int,
        minClearanceMm: Int = 50,
        toleranceMm: Int = 10
    ) {
        self.id = id
        self.category = category
        self.name = name
        self.standardWidthMm = standardWidthMm
        self.standardDepthMm = standardDepthMm
        self.standardHeightMm = standardHeightMm
        self.minClearanceMm = minClearanceMm
        self.toleranceMm = toleranceMm
    }
}

public struct KitchenCatalog {
    public static let standardItems: [KitchenCatalogItem] = [
        KitchenCatalogItem(
            id: "cab-base-standard",
            category: "cabinet-base",
            name: "Standard Base Cabinet (600mm)",
            standardWidthMm: 600,
            standardDepthMm: 600,
            standardHeightMm: 870,
            minClearanceMm: 20,
            toleranceMm: 10
        ),
        KitchenCatalogItem(
            id: "cab-wall-standard",
            category: "cabinet-wall",
            name: "Upper Wall Cabinet (600mm)",
            standardWidthMm: 600,
            standardDepthMm: 350,
            standardHeightMm: 720,
            minClearanceMm: 20,
            toleranceMm: 10
        ),
        KitchenCatalogItem(
            id: "cab-tall-pantry",
            category: "cabinet-tall",
            name: "Full Height Pantry Cabinet",
            standardWidthMm: 600,
            standardDepthMm: 600,
            standardHeightMm: 2150,
            minClearanceMm: 20,
            toleranceMm: 10
        ),
        KitchenCatalogItem(
            id: "app-refrigerator-french",
            category: "appliance",
            name: "French Door Refrigerator",
            standardWidthMm: 914, // 36-inch
            standardDepthMm: 730,
            standardHeightMm: 1780,
            minClearanceMm: 50,
            toleranceMm: 5 // Critical tight opening
        ),
        KitchenCatalogItem(
            id: "app-range-cooktop",
            category: "appliance",
            name: "Freestanding Range / Cooktop",
            standardWidthMm: 762, // 30-inch
            standardDepthMm: 650,
            standardHeightMm: 914,
            minClearanceMm: 30,
            toleranceMm: 5
        ),
        KitchenCatalogItem(
            id: "app-dishwasher-built-in",
            category: "appliance",
            name: "Built-In Dishwasher",
            standardWidthMm: 600,
            standardDepthMm: 600,
            standardHeightMm: 820,
            minClearanceMm: 15,
            toleranceMm: 5
        ),
        KitchenCatalogItem(
            id: "fixture-sink-double",
            category: "fixture",
            name: "Double Bowl Undermount Sink",
            standardWidthMm: 830,
            standardDepthMm: 530,
            standardHeightMm: 230,
            minClearanceMm: 50,
            toleranceMm: 10
        )
    ]

    public static func item(for category: String) -> KitchenCatalogItem? {
        standardItems.first { $0.category == category || $0.id == category }
    }
}
