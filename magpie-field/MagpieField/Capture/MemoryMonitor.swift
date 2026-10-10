//
//  MemoryMonitor.swift
//  MagpieField
//
//  Memory monitoring utility for tracking RAM usage and leak detection (Layer 2, T-102).
//

import Foundation

#if DEBUG

@MainActor
public final class MemoryMonitor {
    public static let shared = MemoryMonitor()

    private var isMonitoring = false
    private var timer: Timer?
    private var baselineMemory: UInt64 = 0
    private var peakMemory: UInt64 = 0

    private init() {}

    public func startMonitoring(interval: TimeInterval = 5.0) {
        guard !isMonitoring else { return }
        isMonitoring = true
        baselineMemory = currentMemoryUsage()
        peakMemory = baselineMemory

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.logMemoryStatus()
            }
        }
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }

    public func logMemoryStatus() {
        let current = currentMemoryUsage()
        peakMemory = max(peakMemory, current)
        let delta = Int64(current) - Int64(baselineMemory)
        let deltaStr = delta >= 0 ? "+\(formatBytes(UInt64(delta)))" : "-\(formatBytes(UInt64(-delta)))"
        print("📊 [MemoryMonitor] Current: \(formatBytes(current)) | Delta: \(deltaStr) | Peak: \(formatBytes(peakMemory))")
    }

    public func checkpoint(_ label: String) {
        let current = currentMemoryUsage()
        print("📊 [MemoryMonitor] \(label): \(formatBytes(current))")
    }

    private func currentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.resident_size : 0
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / 1_000_000.0
        return String(format: "%.1f MB", mb)
    }
}

#else

@MainActor
public final class MemoryMonitor {
    public static let shared = MemoryMonitor()
    private init() {}
    @inlinable public func startMonitoring(interval: TimeInterval = 5.0) {}
    @inlinable public func stopMonitoring() {}
    @inlinable public func logMemoryStatus() {}
    @inlinable public func checkpoint(_ label: String) {}
}

#endif
