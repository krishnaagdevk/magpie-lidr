//
//  DrawParameters.swift
//  MagpieField
//
//  Display constants and sizing for SpriteKit 2D floor plan rendering (Layer 3).
//

import UIKit
import SpriteKit

public struct DrawParameters {
    public static let floorPlanSize = CGSize(width: 4000, height: 4000)
    public static let floorPlanAnchorPoint = CGPoint(x: 0.5, y: 0.5)
    public static let floorPlanBackgroundColor = UIColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 1.0)

    public static let scaleFactor: CGFloat = 180.0 // Pixels per metre

    public static let wallColor = UIColor(red: 0.20, green: 0.25, blue: 0.32, alpha: 1.0)
    public static let wallSelectedColor = UIColor(red: 0.15, green: 0.50, blue: 0.95, alpha: 1.0)
    public static let doorColor = UIColor(red: 0.85, green: 0.45, blue: 0.15, alpha: 1.0)
    public static let windowColor = UIColor(red: 0.20, green: 0.65, blue: 0.85, alpha: 1.0)
    public static let openingColor = UIColor(red: 0.50, green: 0.55, blue: 0.60, alpha: 0.6)

    public static let cabinetColor = UIColor(red: 0.30, green: 0.60, blue: 0.40, alpha: 1.0)
    public static let applianceColor = UIColor(red: 0.80, green: 0.30, blue: 0.30, alpha: 1.0)
    public static let objectSelectedColor = UIColor(red: 0.95, green: 0.60, blue: 0.10, alpha: 1.0)

    public static let criticalDimensionBadgeColor = UIColor(red: 0.85, green: 0.20, blue: 0.20, alpha: 1.0)
    public static let advisoryDimensionBadgeColor = UIColor(red: 0.40, green: 0.45, blue: 0.55, alpha: 1.0)
}
