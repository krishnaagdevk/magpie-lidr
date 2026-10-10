//
//  SurfaceDetailsView.swift
//  MagpieField
//
//  Wall editor sheet providing numeric millimetre adjustments and wall deletion (Layer 3, T-304, T-305, T-306).
//

import SwiftUI
import MagpieCore

public struct SurfaceDetailsView: View {
    @ObservedObject public var viewModel: FloorPlanViewModel
    public let surfaceId: String
    @Binding public var isPresented: Bool

    @State private var lengthMmText: String = ""
    @State private var errorMessage: String? = nil

    public var body: some View {
        NavigationStack {
            Form {
                Section("Wall Dimensions (Millimetres)") {
                    HStack {
                        Text("Length")
                        Spacer()
                        TextField("Length (mm)", text: $lengthMmText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.body, design: .monospaced))
                        Text("mm").foregroundColor(.secondary)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Section("Kitchen Tagging") {
                    Button("Tag as Base Cabinet Run") {
                        viewModel.addKitchenTag(elementId: surfaceId, category: .baseCabinetRun)
                        isPresented = false
                    }
                    Button("Tag as Wall Cabinet Run") {
                        viewModel.addKitchenTag(elementId: surfaceId, category: .wallCabinetRun)
                        isPresented = false
                    }
                    Button("Tag as Tall Pantry Run") {
                        viewModel.addKitchenTag(elementId: surfaceId, category: .tallCabinetRun)
                        isPresented = false
                    }
                }

                Section {
                    Button(role: .destructive) {
                        viewModel.deleteWall(wallId: surfaceId)
                        isPresented = false
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Wall (False Detection)")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Wall")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        guard let mm = Int(lengthMmText), mm > 100, mm < 50000 else {
                            errorMessage = "Please enter a valid length between 100mm and 50,000mm."
                            return
                        }
                        viewModel.updateWallDimension(wallId: surfaceId, newLengthMm: mm)
                        isPresented = false
                    }
                }
            }
            .onAppear {
                if let wall = viewModel.editedPlan.walls.first(where: { $0.id == surfaceId }) {
                    let currentMm = Int(round(wall.dimensions.x * 1000.0))
                    lengthMmText = "\(currentMm)"
                }
            }
        }
    }
}
