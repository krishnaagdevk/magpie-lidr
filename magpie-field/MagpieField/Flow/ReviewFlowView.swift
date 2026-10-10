//
//  ReviewFlowView.swift
//  MagpieField
//
//  2D floor plan review screen allowing wall editing, deletions, tagging, and coverage verification (Layer 3, G3).
//

import SwiftUI
import RoomPlan
import MagpieCore

public struct ReviewFlowView: View {
    public let siteId: String
    public let workerName: String
    public let roomLabel: String
    public let rawRoom: CapturedRoom?
    public let photos: [PhotoCaptureManager.CapturedPhoto]

    @StateObject private var viewModel: FloorPlanViewModel
    @State private var isNavigatingToTapeGate: Bool = false
    @State private var showCoverageSheet: Bool = false
    @State private var showAddFurnitureSheet: Bool = false

    public init(
        siteId: String,
        workerName: String,
        roomLabel: String,
        rawRoom: CapturedRoom?,
        photos: [PhotoCaptureManager.CapturedPhoto] = []
    ) {
        self.siteId = siteId
        self.workerName = workerName
        self.roomLabel = roomLabel
        self.rawRoom = rawRoom
        self.photos = photos

        let plan = rawRoom != nil ? EditedPlan(capturedRoom: rawRoom!) : EditedPlan()
        _viewModel = StateObject(wrappedValue: FloorPlanViewModel(plan: plan))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Advisory Banner
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.amber400)
                Text("Scanned dimensions are approximate. Verify critical dimensions with a tape.")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(red: 0.15, green: 0.18, blue: 0.22))
            .foregroundColor(.white)

            // 2D SpriteKit Scene
            ZStack(alignment: .bottomTrailing) {
                FloorPlanSceneView(viewModel: viewModel)
                    .ignoresSafeArea(edges: .horizontal)

                // Quick Action Floating Buttons
                VStack(spacing: 12) {
                    Button {
                        showCoverageSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(viewModel.coverageReport.isClosed ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(viewModel.coverageReport.isClosed ? "Polygon Closed" : "Open Gap (\(viewModel.coverageReport.gapMm)mm)")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .shadow(radius: 2)
                    }

                    Button {
                        showAddFurnitureSheet = true
                    } label: {
                        Image(systemName: "plus.rectangle.on.rectangle")
                            .font(.system(size: 18, weight: .bold))
                            .padding(12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                }
                .padding(16)
            }

            // Bottom Action Bar
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(viewModel.editedPlan.walls.count) Walls | \(viewModel.editedPlan.objects.count) Objects")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "Floor Area: %.2f m²", viewModel.coverageReport.floorAreaM2))
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    Spacer()

                    Button {
                        isNavigatingToTapeGate = true
                    } label: {
                        Text("Continue to Tape Gate →")
                            .fontWeight(.bold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(UIColor.secondarySystemBackground))
        }
        .navigationTitle("Review & Correct Scan")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.isEditingWallLength) {
            if let surface = viewModel.selectedSurface {
                SurfaceDetailsView(
                    viewModel: viewModel,
                    surfaceId: surface.id,
                    isPresented: $viewModel.isEditingWallLength
                )
            }
        }
        .sheet(isPresented: $viewModel.isTaggingKitchen) {
            if let obj = viewModel.selectedObject {
                ObjectDetailsView(
                    viewModel: viewModel,
                    objectId: obj.id,
                    isPresented: $viewModel.isTaggingKitchen
                )
            }
        }
        .sheet(isPresented: $showAddFurnitureSheet) {
            AddFurnitureView(viewModel: viewModel, isPresented: $showAddFurnitureSheet)
        }
        .sheet(isPresented: $showCoverageSheet) {
            coverageSummarySheet
        }
        .navigationDestination(isPresented: $isNavigatingToTapeGate) {
            TapeGateView(
                siteId: siteId,
                workerName: workerName,
                roomLabel: roomLabel,
                plan: viewModel.editedPlan,
                rawRoom: rawRoom,
                photos: photos
            )
        }
    }

    private var coverageSummarySheet: some View {
        NavigationStack {
            List {
                Section("Perimeter Closure Status") {
                    HStack {
                        Text("Wall Count")
                        Spacer()
                        Text("\(viewModel.coverageReport.wallCount)")
                    }
                    HStack {
                        Text("Closure Status")
                        Spacer()
                        Text(viewModel.coverageReport.isClosed ? "CLOSED (Pass)" : "OPEN (Flagged)")
                            .foregroundColor(viewModel.coverageReport.isClosed ? .green : .red)
                            .fontWeight(.bold)
                    }
                    HStack {
                        Text("Endpoint Gap")
                        Spacer()
                        Text("\(viewModel.coverageReport.gapMm) mm")
                    }
                    HStack {
                        Text("Perimeter Shortfall")
                        Spacer()
                        Text(String(format: "%.1f%%", viewModel.coverageReport.shortfallPercent))
                    }
                }

                if !viewModel.coverageReport.warnings.isEmpty {
                    Section("Warnings") {
                        ForEach(viewModel.coverageReport.warnings, id: \.self) { warn in
                            Label(warn, systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Scan Quality Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showCoverageSheet = false }
                }
            }
        }
    }
}

extension Color {
    static let amber400 = Color(red: 0.98, green: 0.75, blue: 0.18)
}
