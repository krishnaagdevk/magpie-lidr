//
//  FloorPlanObject.swift
//  MagpieField
//
//  SpriteKit 2D visual representation of a detected/tagged object (cabinet, appliance, sink).
//

import SpriteKit
import UIKit
import MagpieCore

public final class FloorPlanObject: SKNode {
    public let id: String
    public var category: String
    public var dimensions: Vec3
    public var isKitchenTagged: Bool = false

    private let shapeNode = SKShapeNode()
    private let labelNode = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private var isSelectedState = false

    public init(id: String, category: String, dimensions: Vec3, position: CGPoint, rotationZ: CGFloat) {
        self.id = id
        self.category = category
        self.dimensions = dimensions

        super.init()
        self.name = id
        self.position = position
        self.zRotation = rotationZ

        setupShape()
        setupLabel()
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupShape() {
        let width = CGFloat(dimensions.x) * DrawParameters.scaleFactor
        let depth = CGFloat(dimensions.z) * DrawParameters.scaleFactor
        let rect = CGRect(x: -width / 2.0, y: -depth / 2.0, width: width, height: depth)

        shapeNode.path = CGPath(rect: rect, transform: nil)
        shapeNode.strokeColor = .white
        shapeNode.lineWidth = 1.5

        updateColor()
        addChild(shapeNode)
    }

    private func setupLabel() {
        labelNode.fontSize = 11
        labelNode.fontColor = .white
        labelNode.verticalAlignmentMode = .center
        labelNode.horizontalAlignmentMode = .center
        labelNode.text = category.capitalized
        addChild(labelNode)
    }

    public func select() {
        isSelectedState = true
        updateColor()
    }

    public func deselect() {
        isSelectedState = false
        updateColor()
    }

    private func updateColor() {
        if isSelectedState {
            shapeNode.fillColor = DrawParameters.objectSelectedColor
        } else if category.contains("cabinet") || category.contains("storage") {
            shapeNode.fillColor = DrawParameters.cabinetColor
        } else {
            shapeNode.fillColor = DrawParameters.applianceColor
        }
    }
}
