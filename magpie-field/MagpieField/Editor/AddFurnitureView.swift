//
//  AddFurnitureView.swift
//  MagpieField
//
//  Furniture and obstacle placement sheet for adding missed fixtures.
//

import SwiftUI
import MagpieCore

public struct AddFurnitureView: View {
    @ObservedObject public var viewModel: FloorPlanViewModel
    @Binding public var isPresented: Bool

    public var body: some View {
        NavigationStack {
            List(KitchenCatalog.standardItems) { item in
                Button {
                    let newObject = PlanObject(
                        id: UUID().uuidString,
                        category: item.category,
                        transform: Mat4.identity,
                        dimensions: Vec3(
                            x: Float(item.standardWidthMm) / 1000.0,
                            y: Float(item.standardHeightMm) / 1000.0,
                            z: Float(item.standardDepthMm) / 1000.0
                        )
                    )
                    viewModel.editedPlan.objects.append(newObject)
                    isPresented = false
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name).fontWeight(.semibold)
                        Text("\(item.standardWidthMm) × \(item.standardDepthMm) × \(item.standardHeightMm) mm")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Add Cabinet / Appliance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}
