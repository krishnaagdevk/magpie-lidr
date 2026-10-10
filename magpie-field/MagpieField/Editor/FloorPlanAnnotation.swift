//
//  FloorPlanAnnotation.swift
//  MagpieField
//
//  SpriteKit dimension line and provenance badge annotation.
//

import SpriteKit
import UIKit
import MagpieCore

public final class FloorPlanAnnotation: SKNode {
    public let elementId: String
    public var measurement: Measurement
    private let textNode = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let badgeBgNode = SKShapeNode()

    public init(elementId: String, measurement: Measurement, position: CGPoint) {
        self.elementId = elementId
        self.measurement = measurement
        super.init()
        self.position = position
        setupBadge()
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupBadge() {
        let isCritical = measurement.critical
        let isTape = measurement.provenance == .tape

        textNode.fontSize = 11
        textNode.fontColor = .white
        textNode.verticalAlignmentMode = .center
        textNode.horizontalAlignmentMode = .center

        let provLabel = isTape ? "TAPE" : "ADVISORY"
        textNode.text = "\(measurement.valueMm) mm [\(provLabel)]"

        let textWidth = CGFloat(textNode.text?.count ?? 10) * 7.5 + 16
        let rect = CGRect(x: -textWidth / 2.0, y: -12, width: textWidth, height: 24)

        badgeBgNode.path = CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil)
        badgeBgNode.fillColor = isCritical ? DrawParameters.criticalDimensionBadgeColor : DrawParameters.advisoryDimensionBadgeColor
        badgeBgNode.strokeColor = .white
        badgeBgNode.lineWidth = 1.0

        addChild(badgeBgNode)
        addChild(textNode)
    }

    public func highlight() {
        badgeBgNode.strokeColor = .systemYellow
        badgeBgNode.lineWidth = 2.5
    }

    public func removeHighlight() {
        badgeBgNode.strokeColor = .white
        badgeBgNode.lineWidth = 1.0
    }
}
