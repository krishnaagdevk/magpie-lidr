//
//  Measurement.swift
//  MagpieCore
//
//  The provenance model for room and kitchen dimensions (Layer 1).
//  Every dimension carries explicit provenance.
//

import Foundation

public enum DimensionProvenance: String, Codable, Equatable {
    case scanned    // RoomPlan raw value (Advisory)
    case tape       // Physical tape measure input (Governing)
    case derived    // Computed from other dimensions
    case calibrated // Scanned and adjusted by biasFactor
}

public struct Measurement: Codable, Equatable, Identifiable {
    public var id: String
    public var kind: String // "wall", "opening", "ceiling", "diagonal", "gap", "object"
    public var label: String
    /// Governing value in millimetres (tape if present, else scanned/calibrated)
    public var valueMm: Int
    /// Raw or bias-calibrated scanned value in millimetres
    public var valueScannedMm: Int
    public var provenance: DimensionProvenance
    public var critical: Bool
    public var toleranceMm: Int
    public var deviationMm: Int
    public var withinTolerance: Bool
    public var note: String

    public init(
        id: String,
        kind: String,
        label: String,
        valueMm: Int,
        valueScannedMm: Int,
        provenance: DimensionProvenance,
        critical: Bool = false,
        toleranceMm: Int = 10,
        note: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.valueMm = valueMm
        self.valueScannedMm = valueScannedMm
        self.provenance = provenance
        self.critical = critical
        self.toleranceMm = toleranceMm
        let deviation = abs(valueMm - valueScannedMm)
        self.deviationMm = deviation
        self.withinTolerance = deviation <= toleranceMm
        self.note = note
    }

    /// Combines multiple measurements to derive a dimension.
    /// Rule: derived inherits the weakest provenance of its inputs.
    public static func derive(
        id: String,
        kind: String,
        label: String,
        valueMm: Int,
        valueScannedMm: Int,
        inputs: [Measurement],
        critical: Bool = false,
        toleranceMm: Int = 10,
        note: String = ""
    ) -> Measurement {
        var prov: DimensionProvenance = .derived

        // If any input is scanned, weakest is scanned
        if inputs.contains(where: { $0.provenance == .scanned }) {
            prov = .scanned
        } else if inputs.contains(where: { $0.provenance == .calibrated }) {
            prov = .calibrated
        } else if inputs.allSatisfy({ $0.provenance == .tape }) && !inputs.isEmpty {
            // Even if all inputs are tape, derived is computed
            prov = .derived
        }

        return Measurement(
            id: id,
            kind: kind,
            label: label,
            valueMm: valueMm,
            valueScannedMm: valueScannedMm,
            provenance: prov,
            critical: critical,
            toleranceMm: toleranceMm,
            note: note
        )
    }
}
