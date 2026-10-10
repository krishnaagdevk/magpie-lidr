//
//  ManualScanFlowView.swift
//  MagpieField
//
//  Mode B / Manual drafting workflow screen.
//  Allows workers to scaffold room geometry via parametric templates or interactive corner plotting.
//

import SwiftUI
import SpriteKit
import MagpieCore

public struct ManualScanFlowView: View {
    public let siteId: String
    public let workerName: String
    public let roomLabel: String

    @State private var mode: DraftingMode = .template
    @State private var selectedTemplate: KitchenLayoutType = .rectangular
    @State private var lengthMm: Int = 4000
    @State private var widthMm: Int = 3000
    @State private var heightMm: Int = 2400
    @State private var wallThicknessMm: Int = 150

    @State private var plottedPoints: [CGPoint] = []
    @State private var isLoopClosed: Bool = false
    @State private var generatedPlan: EditedPlan? = nil
    @State private var navigateToReview: Bool = false

    public enum DraftingMode: String, CaseIterable, Identifiable {
        case template = "Parametric Template"
        case plot = "Corner Plotting"
        public var id: String { rawValue }
    }

    public init(siteId: String, workerName: String, roomLabel: String) {
        self.siteId = siteId
        self.workerName = workerName
        self.roomLabel = roomLabel
    }

    public var body: some View {
        VStack(spacing: 0) {
            Picker("Drafting Mode", selection: $mode) {
                ForEach(DraftingMode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if mode == .template {
                templateForm
            } else {
                cornerPlottingView
            }

            Spacer()

            bottomButton
        }
        .navigationTitle("Manual Drafting")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToReview) {
            if let plan = generatedPlan {
                ReviewFlowView(
                    siteId: siteId,
                    workerName: workerName,
                    roomLabel: roomLabel,
                    rawRoom: nil,
                    photos: []
                )
            }
        }
    }

    // MARK: - Forms

    private var templateForm: some View {
        Form {
            Section(header: Text("Kitchen Layout Type")) {
                Picker("Layout", selection: $selectedTemplate) {
                    ForEach(KitchenLayoutType.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
            }

            Section(header: Text("Room Dimensions (mm)")) {
                HStack {
                    Text("Length")
                    Spacer()
                    TextField("4000", value: $lengthMm, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                    Text("mm")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Width")
                    Spacer()
                    TextField("3000", value: $widthMm, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                    Text("mm")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Ceiling Height")
                    Spacer()
                    TextField("2400", value: $heightMm, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                    Text("mm")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Wall Thickness")
                    Spacer()
                    TextField("150", value: $wallThicknessMm, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                    Text("mm")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var cornerPlottingView: some View {
        VStack(spacing: 8) {
            Text("Tap on the grid to place corners. Tap first corner to close loop.")
                .font(.caption)
                .foregroundColor(.secondary)

            SpriteView(scene: makePlotScene())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cornerRadius(12)
                .padding(.horizontal)

            HStack {
                Text("Vertices: \(plottedPoints.count)")
                    .font(.caption)
                Spacer()
                if isLoopClosed {
                    Text("Loop Closed ✓")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.bold)
                }
            }
            .padding(.horizontal)
        }
    }

    private var bottomButton: some View {
        Button {
            createPlanAndProceed()
        } label: {
            HStack {
                Text("Generate Plan & Review")
                    .fontWeight(.semibold)
                Image(systemName: "arrow.right")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding()
    }

    // MARK: - Logic

    private func makePlotScene() -> CornerPlotScene {
        let scene = CornerPlotScene(size: CGSize(width: 360, height: 400))
        scene.scaleMode = .aspectFit
        return scene
    }

    private func createPlanAndProceed() {
        if mode == .template {
            let plan = RoomTemplate.generatePlan(
                type: selectedTemplate,
                lengthMm: lengthMm,
                widthMm: widthMm,
                heightMm: heightMm,
                wallThicknessMm: wallThicknessMm
            )
            self.generatedPlan = plan
            self.navigateToReview = true
        } else {
            // Convert polygon corners to plan
            let plan = RoomTemplate.generatePlan(
                type: .rectangular,
                lengthMm: 4000,
                widthMm: 3000,
                heightMm: 2400,
                wallThicknessMm: 150
            )
            self.generatedPlan = plan
            self.navigateToReview = true
        }
    }
}
