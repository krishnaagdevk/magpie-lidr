//
//  RoomTemplate.swift
//  MagpieField
//
//  Parametric room template generator for manual drafting and standard kitchen layouts.
//

import Foundation
import MagpieCore

public enum KitchenLayoutType: String, CaseIterable, Identifiable {
    case rectangular = "Single Wall / Rectangular"
    case lShaped = "L-Shaped Kitchen"
    case uShaped = "U-Shaped Kitchen"
    case galley = "Galley Kitchen"

    public var id: String { rawValue }
}

public struct RoomTemplate {

    /// Generates an EditedPlan based on a chosen template and user-supplied dimension parameters in millimetres.
    public static func generatePlan(
        type: KitchenLayoutType,
        lengthMm: Int = 4000,
        widthMm: Int = 3000,
        heightMm: Int = 2400,
        wallThicknessMm: Int = 150
    ) -> EditedPlan {
        var plan = EditedPlan()
        let hMeters = Float(heightMm) / 1000.0
        let thMeters = Float(wallThicknessMm) / 1000.0

        switch type {
        case .rectangular:
            let lMeters = Float(lengthMm) / 1000.0
            let wMeters = Float(widthMm) / 1000.0

            // 4 walls
            // North (Y+)
            plan.walls.append(PlanWall(
                identifier: UUID().uuidString,
                dimensions: PlanVector3(x: lMeters, y: hMeters, z: thMeters),
                transform: [1,0,0,0, 0,1,0,0, 0,0,1,0, 0, hMeters/2, wMeters/2, 1]
            ))
            // South (Y-)
            plan.walls.append(PlanWall(
                identifier: UUID().uuidString,
                dimensions: PlanVector3(x: lMeters, y: hMeters, z: thMeters),
                transform: [1,0,0,0, 0,1,0,0, 0,0,1,0, 0, hMeters/2, -wMeters/2, 1]
            ))
            // East (X+)
            plan.walls.append(PlanWall(
                identifier: UUID().uuidString,
                dimensions: PlanVector3(x: wMeters, y: hMeters, z: thMeters),
                transform: [0,0,1,0, 0,1,0,0, -1,0,0,0, lMeters/2, hMeters/2, 0, 1]
            ))
            // West (X-)
            plan.walls.append(PlanWall(
                identifier: UUID().uuidString,
                dimensions: PlanVector3(x: wMeters, y: hMeters, z: thMeters),
                transform: [0,0,1,0, 0,1,0,0, -1,0,0,0, -lMeters/2, hMeters/2, 0, 1]
            ))

        case .lShaped:
            let lMeters = Float(lengthMm) / 1000.0
            let wMeters = Float(widthMm) / 1000.0
            let cutLMeters = lMeters * 0.4
            let cutWMeters = wMeters * 0.4

            // L-shape with 6 walls
            // Wall 1: Main North
            plan.walls.append(PlanWall(
                identifier: UUID().uuidString,
                dimensions: PlanVector3(x: lMeters, y: hMeters, z: thMeters),
                transform: [1,0,0,0, 0,1,0,0, 0,0,1,0, 0, hMeters/2, wMeters/2, 1]
            ))
            // Wall 2: East
            plan.walls.append(PlanWall(
                identifier: UUID().uuidString,
                dimensions: PlanVector3(x: wMeters, y: hMeters, z: thMeters),
                transform: [0,0,1,0, 0,1,0,0, -1,0,0,0, lMeters/2, hMeters/2, 0, 1]
            ))
            // Wall 3: South partial
            plan.walls.append(PlanWall(
                identifier: UUID().uuidString,
                dimensions: PlanVector3(x: lMeters - cutLMeters, y: hMeters, z: thMeters),
                transform: [1,0,0,0, 0,1,0,0, 0,0,1,0, cutLMeters/2, hMeters/2, -wMeters/2, 1]
            ))
            // Wall 4: Inner North
            plan.walls.append(PlanWall(
                identifier: UUID().uuidString,
                dimensions: PlanVector3(x: cutWMeters, y: hMeters, z: thMeters),
                transform: [0,0,1,0, 0,1,0,0, -1,0,0,0, cutLMeters - lMeters/2, hMeters/2, cutWMeters/2 - wMeters/2, 1]
            ))
            // Wall 5: Inner West
            plan.walls.append(PlanWall(
                identifier: UUID().uuidString,
                dimensions: PlanVector3(x: cutLMeters, y: hMeters, z: thMeters),
                transform: [1,0,0,0, 0,1,0,0, 0,0,1,0, -lMeters/2 + cutLMeters/2, hMeters/2, cutWMeters - wMeters/2, 1]
            ))
            // Wall 6: Main West
            plan.walls.append(PlanWall(
                identifier: UUID().uuidString,
                dimensions: PlanVector3(x: wMeters - cutWMeters, y: hMeters, z: thMeters),
                transform: [0,0,1,0, 0,1,0,0, -1,0,0,0, -lMeters/2, hMeters/2, cutWMeters/2, 1]
            ))

        case .uShaped, .galley:
            let lMeters = Float(lengthMm) / 1000.0
            let wMeters = Float(widthMm) / 1000.0

            // Baseline box with room section
            plan.walls.append(PlanWall(
                identifier: UUID().uuidString,
                dimensions: PlanVector3(x: lMeters, y: hMeters, z: thMeters),
                transform: [1,0,0,0, 0,1,0,0, 0,0,1,0, 0, hMeters/2, wMeters/2, 1]
            ))
            plan.walls.append(PlanWall(
                identifier: UUID().uuidString,
                dimensions: PlanVector3(x: lMeters, y: hMeters, z: thMeters),
                transform: [1,0,0,0, 0,1,0,0, 0,0,1,0, 0, hMeters/2, -wMeters/2, 1]
            ))
            plan.walls.append(PlanWall(
                identifier: UUID().uuidString,
                dimensions: PlanVector3(x: wMeters, y: hMeters, z: thMeters),
                transform: [0,0,1,0, 0,1,0,0, -1,0,0,0, lMeters/2, hMeters/2, 0, 1]
            ))
            plan.walls.append(PlanWall(
                identifier: UUID().uuidString,
                dimensions: PlanVector3(x: wMeters, y: hMeters, z: thMeters),
                transform: [0,0,1,0, 0,1,0,0, -1,0,0,0, -lMeters/2, hMeters/2, 0, 1]
            ))
        }

        plan.sections.append(PlanSection(
            center: [0, 0, 0],
            label: "Kitchen",
            displayName: "Kitchen",
            color: "#4f46e5"
        ))

        return plan
    }
}
