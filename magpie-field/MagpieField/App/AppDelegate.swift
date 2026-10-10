//
//  AppDelegate.swift
//  MagpieField
//
//  Application lifecycle delegate for background uploads and setup.
//

import UIKit

public final class AppDelegate: NSObject, UIApplicationDelegate {
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _ = HapticFeedbackManager.shared
        #if DEBUG
        MemoryMonitor.shared.startMonitoring()
        #endif
        return true
    }

    public func applicationWillTerminate(_ application: UIApplication) {
        #if DEBUG
        MemoryMonitor.shared.stopMonitoring()
        #endif
    }
}
