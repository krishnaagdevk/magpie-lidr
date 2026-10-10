//
//  SiteSetupView.swift
//  MagpieField
//
//  Initial setup screen for capturing site ID, worker identity, and bias calibration (Layer 3, T-404).
//

import SwiftUI
import MagpieCore

public struct SiteSetupView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var workerName: String = ""
    @State private var siteId: String = ""
    @State private var roomLabel: String = "Kitchen"
    @State private var errorMessage: String? = nil
    @State private var isNavigatingToScan: Bool = false

    // Bias Calibration sheet
    @State private var showCalibration: Bool = false
    @State private var calScannedMm: String = "2000"
    @State private var calTapeMm: String = "2000"

    public var body: some View {
        NavigationStack {
            Form {
                Section("Site Identity") {
                    TextField("Worker Name", text: $workerName)
                        .autocapitalization(.words)

                    TextField("Site ID (e.g., SITE-2026-KITCHEN-01)", text: $siteId)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)

                    Picker("Room Label", selection: $roomLabel) {
                        Text("Kitchen").tag("Kitchen")
                        Text("Main Kitchen").tag("Main Kitchen")
                        Text("Pantry").tag("Pantry")
                        Text("Dining & Kitchen").tag("Dining & Kitchen")
                        Text("Custom Room").tag("Custom Room")
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Section("Device Bias Calibration") {
                    HStack {
                        Text("Scale Factor")
                        Spacer()
                        Text(String(format: "%.4f", settings.deviceBiasFactor))
                            .foregroundColor(.secondary)
                            .font(.system(.body, design: .monospaced))
                    }

                    Button("Calibrate Device Against Tape...") {
                        showCalibration = true
                    }
                }

                Section {
                    Button {
                        validateAndStart()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Start LiDAR Scan", systemImage: "viewfinder")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.blue)
                    .foregroundColor(.white)
                }
            }
            .navigationTitle("New Site Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                workerName = settings.lastWorkerName
                siteId = settings.lastSiteId.isEmpty ? "SITE-\(Int.random(in: 1000...9999))" : settings.lastSiteId
            }
            .sheet(isPresented: $showCalibration) {
                calibrationSheet
            }
            .navigationDestination(isPresented: $isNavigatingToScan) {
                ScanFlowView(
                    siteId: siteId,
                    workerName: workerName,
                    roomLabel: roomLabel
                )
            }
        }
    }

    private func validateAndStart() {
        do {
            try CaptureMetadata.validateSiteId(siteId)
            guard !workerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                errorMessage = "Worker name cannot be blank."
                return
            }
            settings.lastWorkerName = workerName
            settings.lastSiteId = siteId
            errorMessage = nil
            isNavigatingToScan = true
        } catch let err as SiteIdValidationError {
            errorMessage = err.description
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var calibrationSheet: some View {
        NavigationStack {
            Form {
                Section("1-Point Reference Calibration") {
                    Text("Measure a known doorway or 2-metre baseline with a physical tape.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Text("Scanned Value (mm)")
                        Spacer()
                        TextField("2000", text: $calScannedMm)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Actual Tape (mm)")
                        Spacer()
                        TextField("2000", text: $calTapeMm)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Device Calibration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCalibration = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Factor") {
                        if let s = Float(calScannedMm), let t = Float(calTapeMm), s > 0 {
                            settings.updateCalibration(tapeMm: t, scannedMm: s)
                        }
                        showCalibration = false
                    }
                }
            }
        }
    }
}
