//
//  ObjectDetailsView.swift
//  MagpieField
//
//  Object tagging and kitchen appliance classification sheet (Layer 3, T-401, T-402).
//

import SwiftUI
import MagpieCore

public struct ObjectDetailsView: View {
    @ObservedObject public var viewModel: FloorPlanViewModel
    public let objectId: String
    @Binding public var isPresented: Bool

    public var body: some View {
        NavigationStack {
            List {
                Section("Assign Kitchen Category") {
                    ForEach(KitchenTagCategory.allCases, id: \.self) { category in
                        Button {
                            viewModel.addKitchenTag(elementId: objectId, category: category)
                            isPresented = false
                        } label: {
                            HStack {
                                Text(category.displayName)
                                Spacer()
                                if category.isCriticalByDefault {
                                    Text("CRITICAL")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.15))
                                        .foregroundColor(.red)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }

                Section("Standard Dimensions") {
                    ForEach(KitchenCatalog.standardItems) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name).fontWeight(.medium)
                            Text("\(item.standardWidthMm)W × \(item.standardDepthMm)D × \(item.standardHeightMm)H mm (±\(item.toleranceMm)mm)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Kitchen Tagging")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }
}
