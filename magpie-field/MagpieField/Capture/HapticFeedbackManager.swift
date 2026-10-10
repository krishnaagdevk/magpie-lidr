//
//  HapticFeedbackManager.swift
//  MagpieField
//
//  Haptic feedback manager for capture milestones, errors, and tape alignment (Layer 2, T-102).
//

import UIKit

@MainActor
public final class HapticFeedbackManager {
    public static let shared = HapticFeedbackManager()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    private init() {
        prepareGenerators()
    }

    public func prepareGenerators() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        notificationFeedback.prepare()
    }

    public func objectDetected() {
        lightImpact.impactOccurred()
    }

    public func wallClosed() {
        mediumImpact.impactOccurred()
    }

    public func tapeMatchSuccess() {
        notificationFeedback.notificationOccurred(.success)
    }

    public func toleranceWarning() {
        notificationFeedback.notificationOccurred(.warning)
    }

    public func scanComplete() {
        notificationFeedback.notificationOccurred(.success)
    }

    public func scanError() {
        notificationFeedback.notificationOccurred(.error)
    }
}
