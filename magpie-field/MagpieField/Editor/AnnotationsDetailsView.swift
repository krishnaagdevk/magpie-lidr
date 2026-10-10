//
//  AnnotationsDetailsView.swift
//  MagpieField
//
//  Dimension annotations inspector.
//

import SwiftUI
import MagpieCore

public struct AnnotationsDetailsView: View {
    @ObservedObject public var viewModel: FloorPlanViewModel
    @Binding public var isPresented: Bool

    public var body: some View {
        NavigationStack {
            List {
                Section("Critical Dimensions") {
                    ForEach(viewModel.editedPlan.dimensions.filter { $0.critical }) { dim in
                        HStack {
                            Text(dim.name)
                            Spacer()
                            Text("\(dim.valueMm) mm")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                        }
                    }
                }

                Section("Advisory Scanned Dimensions") {
                    ForEach(viewModel.editedPlan.dimensions.filter { !$0.critical }) { dim in
                        HStack {
                            Text(dim.name)
                            Spacer()
                            Text("\(dim.valueMm) mm (approx)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Dimensions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }
}
