//
//  TapeGateView.swift
//  MagpieField
//
//  Phase 5 (T-501): Tape verification gate screen.
//  Enforces physical tape verification on critical dimensions, provides deviation bands,
//  supports escape reasons, and generates the signed validation block.
//

import SwiftUI
import MagpieCore

public struct TapeGateView: View {
    public let plan: EditedPlan
    public let siteId: String
    public let workerName: String
    public let roomLabel: String
    public let photos: [PhotoCaptureManager.CapturedPhoto]

    @State private var measurements: [Measurement]
    @State private var tags: [KitchenTag]
    @State private var selectedMeasurementId: String? = nil
    @State private var tapeInputText: String = ""
    @State private var escapeReasonText: String = ""
    @State private var showEscapeSheet: Bool = false
    @State private var showCalibrationAlert: Bool = false
    @State private var calculatedBiasFactor: Float? = nil
    @State private var isNavigatingToExport: Bool = false
    @State private var overrideGate: Bool = false
    @State private var overrideJustification: String = ""
    @State private var showOverrideSheet: Bool = false

    public init(
        plan: EditedPlan,
        siteId: String,
        workerName: String,
        roomLabel: String,
        photos: [PhotoCaptureManager.CapturedPhoto] = []
    ) {
        self.plan = plan
        self.siteId = siteId
        self.workerName = workerName
        self.roomLabel = roomLabel
        self.photos = photos

        let generated = DimensionEngine.generateMeasurements(from: plan)
        let marked = CriticalDimensionRules.markCritical(plan: plan, measurements: generated)
        _measurements = State(initialValue: marked)
        _tags = State(initialValue: [])
    }

    private var validationBlock: ValidationBlock {
        DimensionEngine.computeValidation(measurements: measurements, photosCaptured: photos.count)
    }

    private var criticalMeasurements: [Measurement] {
        measurements.filter { $0.critical }
    }

    private var otherMeasurements: [Measurement] {
        measurements.filter { !$0.critical }
    }

    private var isGatePassed: Bool {
        validationBlock.gateResult == "pass" || overrideGate
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Banner
                headerBanner

                // Measurements List
                List {
                    Section(header: Text("Critical Dimensions (\(criticalMeasurements.count))")) {
                        if criticalMeasurements.isEmpty {
                            Text("No critical dimensions detected.")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        } else {
                            ForEach(criticalMeasurements) { m in
                                MeasurementRowView(
                                    measurement: m,
                                    onTapMeasure: { startTapeEntry(for: m) },
                                    onTapEscape: { startEscapeEntry(for: m) }
                                )
                            }
                        }
                    }

                    if !otherMeasurements.isEmpty {
                        Section(header: Text("Additional Scanned Dimensions (\(otherMeasurements.count))")) {
                            ForEach(otherMeasurements) { m in
                                MeasurementRowView(
                                    measurement: m,
                                    onTapMeasure: { startTapeEntry(for: m) },
                                    onTapEscape: { startEscapeEntry(for: m) }
                                )
                            }
                        }
                    }

                    // Calibration Recommendation Section
                    if let factor = calculatedBiasFactor, abs(factor - 1.0) > 0.005 {
                        Section(header: Text("LiDAR Calibration")) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Computed Scale Bias: \(String(format: "%.3f", factor))x")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("Consistent tape measurements detected a systematic scan variance.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Calibrate") {
                                    applyCalibration(factor: factor)
                                }
                                .buttonStyle(.borderedProminent)
                                .font(.caption)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)

                // Bottom Action Bar
                bottomActionBar
            }
            .navigationTitle("Tape Verification Gate")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEscapeSheet) {
                escapeReasonSheet
            }
            .sheet(isPresented: $showOverrideSheet) {
                overrideGateSheet
            }
            .alert("Enter Tape Measurement (mm)", isPresented: Binding(
                get: { selectedMeasurementId != nil && !showEscapeSheet },
                set: { if !$0 { selectedMeasurementId = nil } }
            )) {
                TextField("Millimetres (e.g. 3450)", text: $tapeInputText)
                    .keyboardType(.numberPad)
                Button("Cancel", role: .cancel) {
                    selectedMeasurementId = nil
                }
                Button("Save") {
                    saveTapeMeasurement()
                }
            } message: {
                if let id = selectedMeasurementId, let m = measurements.first(where: { $0.id == id }) {
                    Text("Scanned: \(m.valueScannedMm ?? m.valueMm) mm. Standard tolerance: ±\(m.toleranceMm) mm.")
                }
            }
            .navigationDestination(isPresented: $isNavigatingToExport) {
                ExportFlowView(
                    plan: plan,
                    measurements: measurements,
                    validation: validationBlock,
                    siteId: siteId,
                    workerName: workerName,
                    roomLabel: roomLabel,
                    photos: photos
                )
            }
        }
    }

    // MARK: - Subviews

    private var headerBanner: some View {
        let block = validationBlock
        let pass = block.gateResult == "pass"
        return VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: pass ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(pass ? .green : (overrideGate ? .orange : .red))
                        Text(pass ? "GATE PASSED" : (overrideGate ? "GATE OVERRIDDEN" : "GATE ACTION REQUIRED"))
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    Text("\(block.criticalWithinTolerance) of \(block.criticalCount) critical dimensions verified within tolerance.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(block.passRate * 100))%")
                        .font(.title2)
                        .fontWeight(.heavy)
                        .foregroundColor(pass ? .green : .orange)
                    Text("Pass Rate")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }

    private var bottomActionBar: some View {
        VStack(spacing: 8) {
            if !isGatePassed {
                HStack {
                    Text("Design contract requires all critical dimensions verified.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Override...") {
                        showOverrideSheet = true
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
            }

            Button {
                isNavigatingToExport = true
            } label: {
                HStack {
                    Text(isGatePassed ? "Proceed to Export" : "Complete Verification to Export")
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isGatePassed ? Color.accentColor : Color.gray.opacity(0.5))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isGatePassed)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }

    private var escapeReasonSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Escape Reason")) {
                    Text("If physical access is impossible (e.g. wall obstructed by built-in appliances), record the justification:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("Reason (e.g. Inaccessible due to existing unit)", text: $escapeReasonText)
                }

                Section {
                    Button("Confirm Escape") {
                        if let id = selectedMeasurementId {
                            measurements = DimensionEngine.applyTapeMeasurement(
                                to: measurements,
                                id: id,
                                tapeMm: nil,
                                escapeReason: escapeReasonText.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        }
                        showEscapeSheet = false
                        selectedMeasurementId = nil
                        escapeReasonText = ""
                        updateBiasFactor()
                    }
                    .disabled(escapeReasonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Record Inaccessible Dimension")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showEscapeSheet = false
                        selectedMeasurementId = nil
                    }
                }
            }
        }
    }

    private var overrideGateSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Gate Override Warning")) {
                    Text("Exporting with unverified critical dimensions marks the package as uncertified. The designer will be required to re-verify on CAD import.")
                        .font(.caption)
                        .foregroundColor(.red)

                    TextField("Supervisor / Worker Justification", text: $overrideJustification)
                }

                Section {
                    Button("Authorize Override", role: .destructive) {
                        overrideGate = true
                        showOverrideSheet = false
                    }
                    .disabled(overrideJustification.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Override Gate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showOverrideSheet = false
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func startTapeEntry(for m: Measurement) {
        selectedMeasurementId = m.id
        tapeInputText = m.provenance == .tape ? "\(m.valueMm)" : ""
    }

    private func startEscapeEntry(for m: Measurement) {
        selectedMeasurementId = m.id
        escapeReasonText = m.note
        showEscapeSheet = true
    }

    private func saveTapeMeasurement() {
        guard let id = selectedMeasurementId, let val = Int(tapeInputText.trimmingCharacters(in: .whitespacesAndNewlines)), val > 0 else {
            selectedMeasurementId = nil
            return
        }

        measurements = DimensionEngine.applyTapeMeasurement(
            to: measurements,
            id: id,
            tapeMm: val,
            toleranceMm: nil,
            escapeReason: nil
        )
        selectedMeasurementId = nil
        tapeInputText = ""
        updateBiasFactor()
    }

    private func updateBiasFactor() {
        calculatedBiasFactor = DimensionEngine.computeBiasFactor(measurements: measurements)
    }

    private func applyCalibration(factor: Float) {
        measurements = DimensionEngine.applyCalibration(to: measurements, biasFactor: factor)
        calculatedBiasFactor = nil
    }
}

// MARK: - MeasurementRowView

private struct MeasurementRowView: View {
    let measurement: Measurement
    let onTapMeasure: () -> Void
    let onTapEscape: () -> Void

    private var deviation: Int? {
        guard let scanned = measurement.valueScannedMm, measurement.provenance == .tape else { return nil }
        return measurement.valueMm - scanned
    }

    private var deviationColor: Color {
        guard let dev = deviation else { return .secondary }
        let absDev = abs(dev)
        if absDev <= measurement.toleranceMm {
            return .green
        } else if absDev <= measurement.toleranceMm * 2 {
            return .orange
        } else {
            return .red
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconName(for: measurement.kind))
                .foregroundColor(.accentColor)
                .frame(width: 24)

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(measurement.label)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if measurement.critical {
                        Text("CRITICAL")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 8) {
                    Text("Scanned: \(measurement.valueScannedMm ?? measurement.valueMm) mm")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("Tol: ±\(measurement.toleranceMm) mm")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if !measurement.note.isEmpty {
                    Text("Note: \(measurement.note)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            // Value & Status
            VStack(alignment: .trailing, spacing: 4) {
                if measurement.provenance == .tape {
                    HStack(spacing: 4) {
                        Text("\(measurement.valueMm) mm")
                            .font(.headline)
                            .fontWeight(.bold)
                        Image(systemName: "ruler.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    if let dev = deviation {
                        Text("\(dev >= 0 ? "+" : "")\(dev) mm")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(deviationColor)
                    }
                } else if !measurement.note.isEmpty {
                    Text("ESCAPED")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                } else {
                    Button {
                        onTapMeasure()
                    } label: {
                        Text("Tape")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundColor(.accentColor)
                            .cornerRadius(6)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTapMeasure()
        }
        .contextMenu {
            Button("Enter Tape Measurement") { onTapMeasure() }
            Button("Mark Inaccessible...") { onTapEscape() }
        }
    }

    private func iconName(for kind: String) -> String {
        switch kind {
        case "wall": return "rectangle.split.3x1"
        case "opening": return "door.left.hand.open"
        case "object": return "cube"
        case "section": return "arrow.up.and.down"
        default: return "ruler"
        }
    }
}
