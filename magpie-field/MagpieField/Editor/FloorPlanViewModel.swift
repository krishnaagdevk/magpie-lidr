//
//  FloorPlanViewModel.swift
//  MagpieField
//
//  ViewModel orchestrating 2D SpriteKit scene interactions and EditedPlan mutations (Layer 3).
//

import SwiftUI
import Combine
import MagpieCore

@MainActor
public final class FloorPlanViewModel: ObservableObject {
    @Published public var editedPlan: EditedPlan
    @Published public var selectedSurface: FloorPlanSurface?
    @Published public var selectedObject: FloorPlanObject?
    @Published public var selectedAnnotation: FloorPlanAnnotation?

    @Published public var isEditingWallLength: Bool = false
    @Published public var isAddingWall: Bool = false
    @Published public var isTaggingKitchen: Bool = false
    @Published public var isTapeGatePresented: Bool = false

    @Published public var validationReport: ValidationResult?
    @Published public var coverageReport: CoverageReport

    public init(plan: EditedPlan) {
        self.editedPlan = plan
        self.coverageReport = RoomPolygon.analyzeCoverage(for: plan)
    }

    public func updateWallDimension(wallId: String, newLengthMm: Int) {
        let newLengthM = Float(newLengthMm) / 1000.0
        editedPlan.updateWall(id: wallId, newDimensions: Vec3(x: newLengthM, y: 2.7, z: 0.15))
        coverageReport = RoomPolygon.analyzeCoverage(for: editedPlan)
        objectWillChange.send()
    }

    public func deleteWall(wallId: String) {
        editedPlan.deleteWall(id: wallId)
        coverageReport = RoomPolygon.analyzeCoverage(for: editedPlan)
        selectedSurface = nil
        objectWillChange.send()
    }

    public func addWall(start: Pt2, end: Pt2) {
        let lengthM = start.distance(to: end)
        let cx = (start.x + end.x) / 2.0
        let cy = (start.y + end.y) / 2.0
        let angle = atan2(end.y - start.y, end.x - start.x)

        let newWall = PlanWall(
            id: UUID().uuidString,
            transform: Mat4(elements: [
                cos(angle), 0, -sin(angle), 0,
                0, 1, 0, 0,
                sin(angle), 0, cos(angle), 0,
                cx, 0, cy, 1
            ]),
            dimensions: Vec3(x: lengthM, y: 2.7, z: 0.15)
        )
        editedPlan.addWall(newWall)
        coverageReport = RoomPolygon.analyzeCoverage(for: editedPlan)
        objectWillChange.send()
    }

    public func addKitchenTag(elementId: String, category: KitchenTagCategory, label: String = "") {
        let tag = KitchenTagItem(elementId: elementId, category: category, label: label)
        editedPlan.kitchenTags.append(tag)
        objectWillChange.send()
    }

    public func refreshCoverage() {
        self.coverageReport = RoomPolygon.analyzeCoverage(for: editedPlan)
    }
}
