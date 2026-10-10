//
//  TakeoffCalculator.swift
//  MagpieField
//
//  Phase 12 / Takeoff: Computes kitchen material takeoffs and linear runs from EditedPlan & KitchenTags (Layer 1).
//  Calculates countertop runs, cabinet lineal metres, backsplash area, baseboard length, and net surface areas.
//

import Foundation
import MagpieCore

public struct KitchenTakeoffSummary: Codable, Equatable {
    public var countertopLinealMeters: Float
    public var countertopAreaSqM: Float
    public var baseCabinetLinealMeters: Float
    public var wallCabinetLinealMeters: Float
    public var tallCabinetLinealMeters: Float
    public var islandCabinetLinealMeters: Float
    public var backsplashAreaSqM: Float
    public var baseboardLinealMeters: Float
    public var flooringAreaSqM: Float
    public var ceilingAreaSqM: Float
    public var grossWallAreaSqM: Float
    public var netWallAreaSqM: Float
    public var doorCount: Int
    public var windowCount: Int

    public init(
        countertopLinealMeters: Float = 0,
        countertopAreaSqM: Float = 0,
        baseCabinetLinealMeters: Float = 0,
        wallCabinetLinealMeters: Float = 0,
        tallCabinetLinealMeters: Float = 0,
        islandCabinetLinealMeters: Float = 0,
        backsplashAreaSqM: Float = 0,
        baseboardLinealMeters: Float = 0,
        flooringAreaSqM: Float = 0,
        ceilingAreaSqM: Float = 0,
        grossWallAreaSqM: Float = 0,
        netWallAreaSqM: Float = 0,
        doorCount: Int = 0,
        windowCount: Int = 0
    ) {
        self.countertopLinealMeters = countertopLinealMeters
        self.countertopAreaSqM = countertopAreaSqM
        self.baseCabinetLinealMeters = baseCabinetLinealMeters
        self.wallCabinetLinealMeters = wallCabinetLinealMeters
        self.tallCabinetLinealMeters = tallCabinetLinealMeters
        self.islandCabinetLinealMeters = islandCabinetLinealMeters
        self.backsplashAreaSqM = backsplashAreaSqM
        self.baseboardLinealMeters = baseboardLinealMeters
        self.flooringAreaSqM = flooringAreaSqM
        self.ceilingAreaSqM = ceilingAreaSqM
        self.grossWallAreaSqM = grossWallAreaSqM
        self.netWallAreaSqM = netWallAreaSqM
        self.doorCount = doorCount
        self.windowCount = windowCount
    }
}

public struct TakeoffCalculator {

    /// Standard standard countertop depth (600mm = 0.60m)
    public static let standardCountertopDepthM: Float = 0.60

    /// Standard backsplash height above counter (600mm = 0.60m)
    public static let standardBacksplashHeightM: Float = 0.60

    /// Computes comprehensive kitchen takeoff metrics from an EditedPlan and associated tags.
    public static func computeTakeoff(
        plan: EditedPlan,
        tags: [KitchenTag] = []
    ) -> KitchenTakeoffSummary {
        var summary = KitchenTakeoffSummary()

        // 1. Flooring area via RoomPolygon
        let polygon = RoomPolygon.from(plan: plan)
        let interiorFloorArea = polygon.computeInteriorArea()
        summary.flooringAreaSqM = interiorFloorArea
        summary.ceilingAreaSqM = interiorFloorArea

        // 2. Wall areas and baseboard perimeter
        var grossWallArea: Float = 0.0
        var totalWallPerimeter: Float = 0.0

        for wall in plan.walls {
            let length = wall.dimensions.x
            let height = wall.dimensions.y
            grossWallArea += (length * height)
            totalWallPerimeter += length
        }
        summary.grossWallAreaSqM = grossWallArea

        // 3. Opening deductions
        var doorWidthTotal: Float = 0.0
        var openingsArea: Float = 0.0

        for door in plan.doors {
            let area = door.dimensions.x * door.dimensions.y
            openingsArea += area
            doorWidthTotal += door.dimensions.x
            summary.doorCount += 1
        }

        for window in plan.windows {
            let area = window.dimensions.x * window.dimensions.y
            openingsArea += area
            summary.windowCount += 1
        }

        for opening in plan.openings {
            let area = opening.dimensions.x * opening.dimensions.y
            openingsArea += area
            doorWidthTotal += opening.dimensions.x
        }

        summary.netWallAreaSqM = max(0.0, grossWallArea - openingsArea)
        summary.baseboardLinealMeters = max(0.0, totalWallPerimeter - doorWidthTotal)

        // 4. Cabinet runs and countertops from tagged elements and objects
        var baseRunM: Float = 0.0
        var wallRunM: Float = 0.0
        var tallRunM: Float = 0.0
        var islandRunM: Float = 0.0

        // Check plan objects
        for obj in plan.objects {
            let cat = (obj.category ?? "").lowercased()
            let length = obj.dimensions.x

            if cat.contains("base-cabinet") || cat.contains("storage") {
                baseRunM += length
            } else if cat.contains("wall-cabinet") || cat.contains("upper") {
                wallRunM += length
            } else if cat.contains("tall") || cat.contains("pantry") || cat.contains("refrigerator") {
                tallRunM += length
            } else if cat.contains("island") || cat.contains("table") {
                islandRunM += length
            }
        }

        // Check kitchen tags on walls
        for tag in tags {
            let cat = tag.category.lowercased()
            if let wall = plan.walls.first(where: { $0.identifier == tag.elementId }) {
                let wallLen = wall.dimensions.x
                if cat == "base-cabinet-run" {
                    baseRunM = max(baseRunM, wallLen)
                } else if cat == "wall-cabinet-run" {
                    wallRunM = max(wallRunM, wallLen)
                } else if cat == "tall-cabinet-run" {
                    tallRunM = max(tallRunM, wallLen)
                } else if cat == "island-run" {
                    islandRunM = max(islandRunM, wallLen)
                }
            }
        }

        summary.baseCabinetLinealMeters = baseRunM
        summary.wallCabinetLinealMeters = wallRunM
        summary.tallCabinetLinealMeters = tallRunM
        summary.islandCabinetLinealMeters = islandRunM

        // Countertop: base cabinets + islands
        let totalCounterRun = baseRunM + islandRunM
        summary.countertopLinealMeters = totalCounterRun
        summary.countertopAreaSqM = totalCounterRun * standardCountertopDepthM

        // Backsplash: base run length * backsplash height
        summary.backsplashAreaSqM = baseRunM * standardBacksplashHeightM

        return summary
    }
}
