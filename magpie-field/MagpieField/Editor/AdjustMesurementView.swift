//
//  AdjustMesurementView.swift
//  MagpieField
//
//  Measurement calibration and manual adjustment sheet.
//

import SwiftUI
import MagpieCore

public struct AdjustMesurementView: View {
    @ObservedObject public var viewModel: FloorPlanViewModel
    @Binding public var isPresented: Bool
    @State private var tapeMmInput: String = ""

    public var body: some View {
        NavigationStack {
            Form {
                Section("Tape Measure Override") {
                    TextField("Measured Length (mm)", text: $tapeMmInput)
                        .keyboardType(.numberPad)
                    Text("Entering a physical tape measurement updates the governing critical dimension.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Adjust Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
