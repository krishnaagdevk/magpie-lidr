//
//  DeviceCapability.swift
//  MagpieField
//
//  Phase 0 (T-005): Device capability & LiDAR sensor hardware gate.
//  Checks RoomPlan support, ARKit world tracking capabilities, camera authorization, and thermal limits.
//

import Foundation
import ARKit
import RoomPlan
import AVFoundation

public struct DeviceCapabilityReport {
    public let isLiDARSupported: Bool
    public let isRoomPlanSupported: Bool
    public let isARKitWorldTrackingSupported: Bool
    public let cameraAuthorizationStatus: AVAuthorizationStatus
    public let thermalState: ProcessInfo.ThermalState
    public let availableDiskSpaceBytes: Int64

    public var canPerformLiDARCapture: Bool {
        return isLiDARSupported && isRoomPlanSupported && cameraAuthorizationStatus != .denied && cameraAuthorizationStatus != .restricted
    }

    public var isThermalThrottling: Bool {
        return thermalState == .serious || thermalState == .critical
    }
}

public class DeviceCapability {

    /// Checks device hardware and software prerequisites for RoomPlan LiDAR scanning.
    public static func checkCapabilities() -> DeviceCapabilityReport {
        let isLiDAR = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)

        let isRoomPlan: Bool
        if #available(iOS 16.0, *) {
            isRoomPlan = RoomCaptureView.isSupported
        } else {
            isRoomPlan = false
        }

        let isARKit = ARWorldTrackingConfiguration.isSupported
        let camStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let thermal = ProcessInfo.processInfo.thermalState

        let diskSpace: Int64
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeSize = attrs[.systemFreeSize] as? NSNumber {
            diskSpace = freeSize.int64Value
        } else {
            diskSpace = 0
        }

        return DeviceCapabilityReport(
            isLiDARSupported: isLiDAR,
            isRoomPlanSupported: isRoomPlan,
            isARKitWorldTrackingSupported: isARKit,
            cameraAuthorizationStatus: camStatus,
            thermalState: thermal,
            availableDiskSpaceBytes: diskSpace
        )
    }

    /// Requests camera authorization if not yet determined.
    public static func requestCameraAccess(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
}
