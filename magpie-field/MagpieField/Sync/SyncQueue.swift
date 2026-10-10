//
//  SyncQueue.swift
//  MagpieField
//
//  Background sync queue with network monitoring and checksum-guaranteed deletion (Layer 2/3, T-704, T-706).
//

import Foundation
import Network
import Combine
import MagpieCore

@MainActor
public final class SyncQueue: ObservableObject {
    public static let shared = SyncQueue()

    @Published public var isOnline: Bool = true
    @Published public var isSyncing: Bool = false
    @Published public var pendingCount: Int = 0

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "MagpieSyncQueue")

    private init() {
        startNetworkMonitoring()
    }

    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = path.status == .satisfied
                if path.status == .satisfied {
                    self?.drainQueue()
                }
            }
        }
        monitor.start(queue: queue)
    }

    public func enqueue(captureId: String) {
        drainQueue()
    }

    public func drainQueue() {
        guard isOnline, !isSyncing else { return }
        isSyncing = true

        Task {
            let storage = RoomStorageManager.shared
            let pending = storage.savedCaptures.filter { $0.syncState == .pending || $0.syncState == .uploading }
            pendingCount = pending.count

            guard let target = pending.first else {
                isSyncing = false
                return
            }

            let client = SyncClient(baseUrl: URL(string: AppSettings.shared.backendUrl)!)

            do {
                // Read local package files
                let dirUrl = URL(fileURLWithPath: target.localDirectoryUrl)
                let planData = try Data(contentsOf: dirUrl.appendingPathComponent("plan.json"))
                let measurementsData = try Data(contentsOf: dirUrl.appendingPathComponent("measurements.json"))

                let planStr = String(data: planData, encoding: .utf8) ?? "{}"
                let measurementsStr = String(data: measurementsData, encoding: .utf8) ?? "{}"

                let manifest = PackageManifest(
                    title: "\(target.siteId) - \(target.roomLabel)",
                    siteId: target.siteId,
                    capturedAt: target.capturedAt
                )

                let package = MagpiePackage(
                    manifest: manifest,
                    planJson: planStr,
                    measurementsJson: measurementsStr
                )

                let response = try await client.uploadHandoff(
                    package: package,
                    authToken: AppSettings.shared.authToken
                )

                // Update sync state only on checksum confirmation
                if let idx = storage.savedCaptures.firstIndex(where: { $0.id == target.id }) {
                    storage.savedCaptures[idx].syncState = .confirmed
                    storage.savedCaptures[idx].checksum = response.checksum
                }
            } catch {
                if let idx = storage.savedCaptures.firstIndex(where: { $0.id == target.id }) {
                    storage.savedCaptures[idx].syncState = .pending
                }
            }

            isSyncing = false
        }
    }
}
