//
//  MeasurementTableExporter.swift
//  MagpieCore
//
//  Serializes measurements.json sidecar payload (Layer 1).
//  Integer millimetres, every dimension carries provenance and deviation.
//

import Foundation

public struct CalibrationBlock: Codable, Equatable {
    public var biasFactor: Float
    public var calibratedAt: String
    public var referenceDescription: String

    public init(
        biasFactor: Float,
        calibratedAt: String,
        referenceDescription: String
    ) {
        self.biasFactor = biasFactor
        self.calibratedAt = calibratedAt
        self.referenceDescription = referenceDescription
    }
}

public struct TolerancesBlock: Codable, Equatable {
    public var wallToWallMm: Int
    public var criticalOpeningMm: Int

    public init(
        wallToWallMm: Int = 10,
        criticalOpeningMm: Int = 5
    ) {
        self.wallToWallMm = wallToWallMm
        self.criticalOpeningMm = criticalOpeningMm
    }
}

public struct RoomMeasurement: Codable, Equatable {
    public var story: Int
    public var label: String
    public var displayName: String
    public var ceilingHeightMm: Int
    public var ceilingHeightProvenance: DimensionProvenance
    public var floorAreaMm2: Int
    public var floorAreaProvenance: DimensionProvenance

    public init(
        story: Int,
        label: String,
        displayName: String,
        ceilingHeightMm: Int,
        ceilingHeightProvenance: DimensionProvenance,
        floorAreaMm2: Int,
        floorAreaProvenance: DimensionProvenance
    ) {
        self.story = story
        self.label = label
        self.displayName = displayName
        self.ceilingHeightMm = ceilingHeightMm
        self.ceilingHeightProvenance = ceilingHeightProvenance
        self.floorAreaMm2 = floorAreaMm2
        self.floorAreaProvenance = floorAreaProvenance
    }
}

public struct MeasurementsPayload: Codable, Equatable {
    public var measurementsVersion: Int
    public var siteId: String
    public var workerName: String
    public var capturedAt: String
    public var deviceModel: String
    public var appVersion: String
    public var captureMode: String
    public var handoffVersion: Int
    public var calibration: CalibrationBlock?
    public var tolerances: TolerancesBlock
    public var rooms: [RoomMeasurement]
    public var dimensions: [Measurement]
    public var kitchenTags: [KitchenTag]
    public var validation: ValidationBlock

    public init(
        measurementsVersion: Int = 1,
        siteId: String,
        workerName: String,
        capturedAt: String,
        deviceModel: String,
        appVersion: String,
        captureMode: String = "lidar",
        handoffVersion: Int = 1,
        calibration: CalibrationBlock? = nil,
        tolerances: TolerancesBlock = TolerancesBlock(),
        rooms: [RoomMeasurement] = [],
        dimensions: [Measurement] = [],
        kitchenTags: [KitchenTag] = [],
        validation: ValidationBlock
    ) {
        self.measurementsVersion = measurementsVersion
        self.siteId = siteId
        self.workerName = workerName
        self.capturedAt = capturedAt
        self.deviceModel = deviceModel
        self.appVersion = appVersion
        self.captureMode = captureMode
        self.handoffVersion = handoffVersion
        self.calibration = calibration
        self.tolerances = tolerances
        self.rooms = rooms
        self.dimensions = dimensions
        self.kitchenTags = kitchenTags
        self.validation = validation
    }
}

public struct MeasurementTableExporter {

    public static func buildPayload(
        siteId: String,
        workerName: String,
        capturedAt: String,
        deviceModel: String,
        appVersion: String,
        captureMode: String = "lidar",
        plan: EditedPlan,
        dimensions: [Measurement],
        kitchenTags: [KitchenTag] = [],
        calibration: CalibrationBlock? = nil,
        tolerances: TolerancesBlock = TolerancesBlock(),
        photosCaptured: Int = 0
    ) -> MeasurementsPayload {
        let stats = ScanStatistics.from(plan: plan)
        let floorAreaMm2 = Int((stats.floorArea * 1_000_000.0).rounded())

        var rooms: [RoomMeasurement] = []
        for sec in plan.sections {
            let chMm = sec.ceilingHeight != nil ? ScanStatistics.toMm(sec.ceilingHeight!) : stats.roomHeightMm
            let room = RoomMeasurement(
                story: sec.story,
                label: sec.label,
                displayName: sec.displayName ?? sec.label,
                ceilingHeightMm: chMm,
                ceilingHeightProvenance: .scanned,
                floorAreaMm2: floorAreaMm2,
                floorAreaProvenance: .scanned
            )
            rooms.append(room)
        }

        if rooms.isEmpty {
            rooms.append(RoomMeasurement(
                story: 0,
                label: "Room",
                displayName: "Room",
                ceilingHeightMm: stats.roomHeightMm,
                ceilingHeightProvenance: .scanned,
                floorAreaMm2: floorAreaMm2,
                floorAreaProvenance: .scanned
            ))
        }

        let valBlock = DimensionEngine.computeValidation(from: dimensions, photosCaptured: photosCaptured)

        return MeasurementsPayload(
            siteId: siteId,
            workerName: workerName,
            capturedAt: capturedAt,
            deviceModel: deviceModel,
            appVersion: appVersion,
            captureMode: captureMode,
            handoffVersion: plan.openplanHandoffVersion,
            calibration: calibration,
            tolerances: tolerances,
            rooms: rooms,
            dimensions: dimensions,
            kitchenTags: kitchenTags,
            validation: valBlock
        )
    }

    public static func exportJSONData(payload: MeasurementsPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        return try encoder.encode(payload)
    }
}
