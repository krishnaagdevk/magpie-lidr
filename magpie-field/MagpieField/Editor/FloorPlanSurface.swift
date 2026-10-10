//
//  FloorPlanSurface.swift
//  MagpieField
//
//  SpriteKit 2D visual representation of a wall, door, or window bound directly to EditedPlan.
//

import SpriteKit
import UIKit
import MagpieCore

public enum SurfaceCategory: String, Sendable {
    case wall
    case door
    case window
    case opening
}

public final class FloorPlanSurface: SKNode {
    public let id: String
    public let category: SurfaceCategory
    public var lengthM: Float
    public var heightM: Float
    public var thicknessM: Float

    private let shapeNode = SKShapeNode()
    private let labelNode = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private var isSelectedState = false

    public init(id: String, category: SurfaceCategory, lengthM: Float, heightM: Float, thicknessM: Float, position: CGPoint, rotationZ: CGFloat) {
        self.id = id
        self.category = category
        self.lengthM = lengthM
        self.heightM = heightM
        self.thicknessM = thicknessM

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
        let width = CGFloat(lengthM) * DrawParameters.scaleFactor
        let depth = max(10, CGFloat(thicknessM) * DrawParameters.scaleFactor)
        let rect = CGRect(x: -width / 2.0, y: -depth / 2.0, width: width, height: depth)

        shapeNode.path = CGPath(rect: rect, transform: nil)
        shapeNode.strokeColor = .clear
        shapeNode.lineWidth = 1.0

        updateColor()
        addChild(shapeNode)
    }

    private func setupLabel() {
        labelNode.fontSize = 12
        labelNode.fontColor = .white
        labelNode.verticalAlignmentMode = .center
        labelNode.horizontalAlignmentMode = .center
        let mm = Int(round(lengthM * 1000.0))
        labelNode.text = "\(mm) mm"
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
            shapeNode.fillColor = DrawParameters.wallSelectedColor
        } else {
            switch category {
            case .wall: shapeNode.fillColor = DrawParameters.wallColor
            case .door: shapeNode.fillColor = DrawParameters.doorColor
            case .window: shapeNode.fillColor = DrawParameters.windowColor
            case .opening: shapeNode.fillColor = DrawParameters.openingColor
            }
        }
    }

    public func updateLength(newLengthM: Float) {
        self.lengthM = newLengthM
        let width = CGFloat(newLengthM) * DrawParameters.scaleFactor
        let depth = max(10, CGFloat(thicknessM) * DrawParameters.scaleFactor)
        let rect = CGRect(x: -width / 2.0, y: -depth / 2.0, width: width, height: depth)
        shapeNode.path = CGPath(rect: rect, transform: nil)
        let mm = Int(round(newLengthM * 1000.0))
        labelNode.text = "\(mm) mm"
    }
}
