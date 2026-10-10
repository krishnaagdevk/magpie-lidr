//
//  AppSettings.swift
//  MagpieField
//
//  Application settings, user defaults, worker defaults, and device bias calibration persistence.
//

import Foundation
import SwiftUI

@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    private enum Keys {
        static let lastWorkerName = "lastWorkerName"
        static let lastSiteId = "lastSiteId"
        static let deviceBiasFactor = "deviceBiasFactor"
        static let defaultToleranceMm = "defaultToleranceMm"
        static let displayUnit = "displayUnit"
        static let autoSaveScans = "autoSaveScans"
        static let backendUrl = "backendUrl"
        static let authToken = "authToken"
    }

    @Published public var lastWorkerName: String {
        didSet { UserDefaults.standard.set(lastWorkerName, forKey: Keys.lastWorkerName) }
    }

    @Published public var lastSiteId: String {
        didSet { UserDefaults.standard.set(lastSiteId, forKey: Keys.lastSiteId) }
    }

    @Published public var deviceBiasFactor: Float {
        didSet { UserDefaults.standard.set(deviceBiasFactor, forKey: Keys.deviceBiasFactor) }
    }

    @Published public var defaultToleranceMm: Int {
        didSet { UserDefaults.standard.set(defaultToleranceMm, forKey: Keys.defaultToleranceMm) }
    }

    @Published public var displayUnit: String {
        didSet { UserDefaults.standard.set(displayUnit, forKey: Keys.displayUnit) }
    }

    @Published public var autoSaveScans: Bool {
        didSet { UserDefaults.standard.set(autoSaveScans, forKey: Keys.autoSaveScans) }
    }

    @Published public var backendUrl: String {
        didSet { UserDefaults.standard.set(backendUrl, forKey: Keys.backendUrl) }
    }

    @Published public var authToken: String {
        didSet { UserDefaults.standard.set(authToken, forKey: Keys.authToken) }
    }

    private init() {
        self.lastWorkerName = UserDefaults.standard.string(forKey: Keys.lastWorkerName) ?? ""
        self.lastSiteId = UserDefaults.standard.string(forKey: Keys.lastSiteId) ?? ""
        let storedBias = UserDefaults.standard.float(forKey: Keys.deviceBiasFactor)
        self.deviceBiasFactor = storedBias > 0.5 && storedBias < 1.5 ? storedBias : 1.0
        let storedTol = UserDefaults.standard.integer(forKey: Keys.defaultToleranceMm)
        self.defaultToleranceMm = storedTol > 0 ? storedTol : 10
        self.displayUnit = UserDefaults.standard.string(forKey: Keys.displayUnit) ?? "millimetres"
        self.autoSaveScans = UserDefaults.standard.object(forKey: Keys.autoSaveScans) != nil ? UserDefaults.standard.bool(forKey: Keys.autoSaveScans) : true
        self.backendUrl = UserDefaults.standard.string(forKey: Keys.backendUrl) ?? "http://localhost:5173"
        self.authToken = UserDefaults.standard.string(forKey: Keys.authToken) ?? ""
    }

    public func updateCalibration(tapeMm: Float, scannedMm: Float) {
        guard scannedMm > 0 else { return }
        let factor = tapeMm / scannedMm
        if factor >= 0.85 && factor <= 1.15 {
            self.deviceBiasFactor = factor
        }
    }

    public func resetToDefaults() {
        self.deviceBiasFactor = 1.0
        self.defaultToleranceMm = 10
        self.displayUnit = "millimetres"
        self.autoSaveScans = true
    }
}
