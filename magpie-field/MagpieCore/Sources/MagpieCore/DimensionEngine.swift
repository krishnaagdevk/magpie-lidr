//
//  DimensionEngine.swift
//  MagpieCore
//
//  Extracts dimensions from EditedPlan, attaches provenance and calibration,
//  and computes validation gate results (Layer 1).
//

import Foundation

public struct ValidationBlock: Codable, Equatable {
    public var criticalCount: Int
    public var criticalWithinTolerance: Int
    public var passRate: Float
    public var gateResult: String // "pass" or "fail"
    public var photosCaptured: Int

    public init(
        criticalCount: Int = 0,
        criticalWithinTolerance: Int = 0,
        passRate: Float = 1.0,
        gateResult: String = "pass",
        photosCaptured: Int = 0
    ) {
        self.criticalCount = criticalCount
        self.criticalWithinTolerance = criticalWithinTolerance
        self.passRate = passRate
        self.gateResult = gateResult
        self.photosCaptured = photosCaptured
    }
}

public struct DimensionEngine {

    /// Generates the initial measurement list from an EditedPlan.
    /// All lengths are converted from metres to integer millimetres at this boundary.
    public static func generateMeasurements(
        from plan: EditedPlan,
        biasFactor: Float? = nil,
        tags: [KitchenTag] = []
    ) -> [Measurement] {
        var list: [Measurement] = []

        let factor = biasFactor ?? 1.0
        let hasCalibration = (biasFactor != nil && abs(factor - 1.0) > 1e-5)

        // 1. Walls
        for wall in plan.walls {
            let scannedMm = ScanStatistics.toMm(wall.dimensions.x)
            let governingMm: Int
            let prov: DimensionProvenance

            if hasCalibration {
                governingMm = ScanStatistics.toMm(wall.dimensions.x * factor)
                prov = .calibrated
            } else {
                governingMm = scannedMm
                prov = .scanned
            }

            let m = Measurement(
                id: wall.identifier,
                kind: "wall",
                label: "Wall \(wall.identifier.prefix(4))",
                valueMm: governingMm,
                valueScannedMm: scannedMm,
                provenance: prov,
                critical: false,
                toleranceMm: 10,
                note: ""
            )
            list.append(m)
        }

        // 2. Openings (doors & windows)
        for door in plan.doors {
            let scannedMm = ScanStatistics.toMm(door.dimensions.x)
            let governingMm = hasCalibration ? ScanStatistics.toMm(door.dimensions.x * factor) : scannedMm
            let prov: DimensionProvenance = hasCalibration ? .calibrated : .scanned

            let m = Measurement(
                id: door.identifier,
                kind: "opening",
                label: "Door \(door.identifier.prefix(4)) (\(door.style ?? "single"))",
                valueMm: governingMm,
                valueScannedMm: scannedMm,
                provenance: prov,
                critical: false,
                toleranceMm: 10,
                note: ""
            )
            list.append(m)
        }

        for win in plan.windows {
            let scannedMm = ScanStatistics.toMm(win.dimensions.x)
            let governingMm = hasCalibration ? ScanStatistics.toMm(win.dimensions.x * factor) : scannedMm
            let prov: DimensionProvenance = hasCalibration ? .calibrated : .scanned

            let m = Measurement(
                id: win.identifier,
                kind: "opening",
                label: "Window \(win.identifier.prefix(4)) (\(win.style ?? "fixed"))",
                valueMm: governingMm,
                valueScannedMm: scannedMm,
                provenance: prov,
                critical: false,
                toleranceMm: 10,
                note: ""
            )
            list.append(m)
        }

        // 3. Ceiling Heights from sections
        for section in plan.sections {
            if let ch = section.ceilingHeight, ch > 0 {
                let scannedMm = ScanStatistics.toMm(ch)
                let governingMm = hasCalibration ? ScanStatistics.toMm(ch * factor) : scannedMm
                let prov: DimensionProvenance = hasCalibration ? .calibrated : .scanned

                let m = Measurement(
                    id: "ceiling-\(section.label)",
                    kind: "ceiling",
                    label: "Ceiling height - \(section.displayName ?? section.label)",
                    valueMm: governingMm,
                    valueScannedMm: scannedMm,
                    provenance: prov,
                    critical: true,
                    toleranceMm: 10,
                    note: ""
                )
                list.append(m)
            }
        }

        // Apply critical dimension rules (including fallback)
        return CriticalDimensionRules.markCritical(plan: plan, measurements: list, tags: tags)
    }

    /// Records a tape measurement for a specific dimension ID.
    /// Never overwrites valueScannedMm. Sets provenance to .tape.
    public static func recordTapeMeasurement(
        in measurements: inout [Measurement],
        id: String,
        tapeValueMm: Int,
        note: String = ""
    ) {
        guard let index = measurements.firstIndex(where: { $0.id == id }) else { return }
        var m = measurements[index]
        m.valueMm = tapeValueMm
        m.provenance = .tape
        m.deviationMm = abs(tapeValueMm - m.valueScannedMm)
        m.withinTolerance = m.deviationMm <= m.toleranceMm
        if !note.isEmpty {
            m.note = note
        }
        measurements[index] = m
    }

    /// Computes the validation block from current measurements.
    public static func computeValidation(
        from measurements: [Measurement],
        photosCaptured: Int = 0
    ) -> ValidationBlock {
        let criticals = measurements.filter { $0.critical }
        let totalCritical = criticals.count
        guard totalCritical > 0 else {
            return ValidationBlock(
                criticalCount: 0,
                criticalWithinTolerance: 0,
                passRate: 1.0,
                gateResult: "pass",
                photosCaptured: photosCaptured
            )
        }

        let inTol = criticals.filter { crit in
            // A critical dimension whose provenance is still .scanned with no documented escape reason
            // is UNVERIFIED and counts against the gate until taped or escaped.
            if crit.provenance == .scanned && crit.note.isEmpty {
                return false
            }
            return crit.withinTolerance
        }.count
        let rate = Float(inTol) / Float(totalCritical)
        // Gate passes only if 100% of critical dimensions are within tolerance
        let result = (inTol == totalCritical) ? "pass" : "fail"

        return ValidationBlock(
            criticalCount: totalCritical,
            criticalWithinTolerance: inTol,
            passRate: rate,
            gateResult: result,
            photosCaptured: photosCaptured
        )
    }

    public static func computeValidation(
        measurements: [Measurement],
        photosCaptured: Int = 0
    ) -> ValidationBlock {
        computeValidation(from: measurements, photosCaptured: photosCaptured)
    }

    public static func applyTapeMeasurement(
        to measurements: [Measurement],
        id: String,
        tapeMm: Int?,
        toleranceMm: Int? = nil,
        escapeReason: String? = nil
    ) -> [Measurement] {
        var copy = measurements
        guard let index = copy.firstIndex(where: { $0.id == id }) else { return copy }
        var m = copy[index]
        if let tol = toleranceMm {
            m.toleranceMm = tol
        }
        if let tape = tapeMm {
            recordTapeMeasurement(in: &copy, id: id, tapeValueMm: tape, note: escapeReason ?? m.note)
            if let tol = toleranceMm {
                copy[index].toleranceMm = tol
                copy[index].withinTolerance = copy[index].deviationMm <= tol
            }
        } else if let reason = escapeReason, !reason.isEmpty {
            m.note = reason
            m.withinTolerance = true
            copy[index] = m
        }
        return copy
    }

    public static func computeBiasFactor(measurements: [Measurement]) -> Float? {
        let tapeMeasurements = measurements.filter { $0.provenance == .tape && $0.valueScannedMm > 0 }
        guard !tapeMeasurements.isEmpty else { return nil }
        let totalTape = tapeMeasurements.reduce(0) { $0 + Double($1.valueMm) }
        let totalScanned = tapeMeasurements.reduce(0) { $0 + Double($1.valueScannedMm) }
        guard totalScanned > 0 else { return nil }
        return Float(totalTape / totalScanned)
    }

    public static func applyCalibration(
        to measurements: [Measurement],
        biasFactor: Float
    ) -> [Measurement] {
        measurements.map { m in
            var updated = m
            if m.provenance != .tape {
                updated.valueMm = ScanStatistics.toMm(Float(m.valueScannedMm) / 1000.0 * biasFactor)
                updated.provenance = .calibrated
                let dev = abs(updated.valueMm - updated.valueScannedMm)
                updated.deviationMm = dev
                updated.withinTolerance = dev <= updated.toleranceMm
            }
            return updated
        }
    }
}

