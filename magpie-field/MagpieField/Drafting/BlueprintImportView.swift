//
//  BlueprintImportView.swift
//  MagpieField
//
//  Mode E / 2D Blueprint & Floorplan photo import and 2-point scale calibration view.
//

import SwiftUI
import PhotosUI
import MagpieCore

public struct BlueprintImportView: View {
    public let siteId: String
    public let workerName: String
    public let roomLabel: String

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var loadedImage: UIImage? = nil
    @State private var point1: CGPoint? = nil
    @State private var point2: CGPoint? = nil
    @State private var referenceDistanceMm: Int = 3000
    @State private var computedMmPerPixel: Float? = nil
    @State private var navigateToDrafting: Bool = false

    public init(siteId: String, workerName: String, roomLabel: String) {
        self.siteId = siteId
        self.workerName = workerName
        self.roomLabel = roomLabel
    }

    public var body: some View {
        VStack(spacing: 16) {
            if let image = loadedImage {
                VStack(spacing: 8) {
                    Text("Tap two points along a known reference wall (e.g. 3000 mm)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(12)
                            .overlay(
                                GeometryReader { geo in
                                    Color.clear
                                        .contentShape(Rectangle())
                                        .onTapGesture { loc in
                                            handleTap(at: loc)
                                        }
                                }
                            )

                        if let p1 = point1 {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 14, height: 14)
                                .position(p1)
                        }

                        if let p2 = point2 {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 14, height: 14)
                                .position(p2)
                        }
                    }
                    .frame(maxHeight: 350)
                    .padding(.horizontal)

                    // Calibration Info
                    HStack {
                        Text("Known Distance:")
                            .font(.subheadline)
                        TextField("3000", value: $referenceDistanceMm, format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                        Text("mm")
                            .foregroundColor(.secondary)
                        Spacer()
                        if let scale = computedMmPerPixel {
                            Text("\(String(format: "%.2f", scale)) mm/px")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)
                    Text("Import Architectural Blueprint / Sketch")
                        .font(.headline)
                    Text("Select a 2D floor plan image or photo of an architectural drawing to calibrate dimensions.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("Select Drawing from Photo Library")
                        }
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }

            Spacer()

            if loadedImage != nil {
                Button {
                    navigateToDrafting = true
                } label: {
                    HStack {
                        Text("Calibrate & Open in Editor")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(point1 != nil && point2 != nil ? Color.accentColor : Color.gray.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(point1 == nil || point2 == nil)
                .padding()
            }
        }
        .navigationTitle("Blueprint Calibration")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    self.loadedImage = uiImage
                }
            }
        }
        .navigationDestination(isPresented: $navigateToDrafting) {
            ManualScanFlowView(
                siteId: siteId,
                workerName: workerName,
                roomLabel: roomLabel
            )
        }
    }

    private func handleTap(at point: CGPoint) {
        if point1 == nil {
            point1 = point
        } else if point2 == nil {
            point2 = point
            recalculateScale()
        } else {
            point1 = point
            point2 = nil
            computedMmPerPixel = nil
        }
    }

    private func recalculateScale() {
        guard let p1 = point1, let p2 = point2 else { return }
        let c1 = CalibrationPoint(x: Float(p1.x), y: Float(p1.y))
        let c2 = CalibrationPoint(x: Float(p2.x), y: Float(p2.y))
        computedMmPerPixel = ScaleCalibration.computeMmPerPixel(
            from: c1,
            to: c2,
            knownDistanceMm: referenceDistanceMm
        )
    }
}
