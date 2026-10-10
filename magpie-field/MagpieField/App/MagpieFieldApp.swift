//
//  MagpieFieldApp.swift
//  MagpieField
//
//  Main SwiftUI App entrypoint for Magpie Field LiDAR capture and tape verification.
//

import SwiftUI
import MagpieCore

@main
struct MagpieFieldApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(settings)
        }
    }
}
