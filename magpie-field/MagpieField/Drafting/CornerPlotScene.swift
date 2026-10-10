//
//  CornerPlotScene.swift
//  MagpieField
//
//  SpriteKit scene for plotting corner vertices manually and building room polygon geometries.
//

import SpriteKit
import SwiftUI
import MagpieCore

public protocol CornerPlotSceneDelegate: AnyObject {
    func cornerPlotSceneDidUpdatePoints(_ points: [CGPoint])
    func cornerPlotSceneDidCloseLoop(_ points: [CGPoint])
}

public class CornerPlotScene: SKScene {
    public weak var plotDelegate: CornerPlotSceneDelegate?

    public private(set) var points: [CGPoint] = []
    public var isClosed: Bool = false

    private var pointNodes: [SKShapeNode] = []
    private var lineNodes: [SKShapeNode] = []
    private var labelNodes: [SKLabelNode] = []
    private var activeLineNode: SKShapeNode?

    public override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.1, green: 0.12, blue: 0.15, alpha: 1.0)
        drawGrid()
    }

    public func addPoint(_ point: CGPoint) {
        if points.count >= 3, let first = points.first {
            let dist = hypot(point.x - first.x, point.y - first.y)
            if dist < 30.0 {
                // Snap to close
                closeLoop()
                return
            }
        }

        points.append(point)
        redraw()
        plotDelegate?.cornerPlotSceneDidUpdatePoints(points)
    }

    public func removeLastPoint() {
        guard !points.isEmpty else { return }
        points.removeLast()
        isClosed = false
        redraw()
        plotDelegate?.cornerPlotSceneDidUpdatePoints(points)
    }

    public func reset() {
        points.removeAll()
        isClosed = false
        redraw()
        plotDelegate?.cornerPlotSceneDidUpdatePoints(points)
    }

    public func closeLoop() {
        guard points.count >= 3 else { return }
        isClosed = true
        redraw()
        plotDelegate?.cornerPlotSceneDidCloseLoop(points)
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isClosed, let touch = touches.first else { return }
        let location = touch.location(in: self)
        addPoint(location)
    }

    private func redraw() {
        // Clear previous nodes
        pointNodes.forEach { $0.removeFromParent() }
        lineNodes.forEach { $0.removeFromParent() }
        labelNodes.forEach { $0.removeFromParent() }
        pointNodes.removeAll()
        lineNodes.removeAll()
        labelNodes.removeAll()

        guard !points.isEmpty else { return }

        // Draw points
        for (idx, pt) in points.enumerated() {
            let dot = SKShapeNode(circleOfRadius: idx == 0 ? 8 : 6)
            dot.position = pt
            dot.fillColor = idx == 0 ? .green : .cyan
            dot.strokeColor = .white
            dot.lineWidth = 1.5
            addChild(dot)
            pointNodes.append(dot)
        }

        // Draw lines
        if points.count > 1 {
            let path = CGMutablePath()
            path.move(to: points[0])
            for i in 1..<points.count {
                path.addLine(to: points[i])
            }
            if isClosed, let first = points.first {
                path.addLine(to: first)
            }

            let line = SKShapeNode(path: path)
            line.strokeColor = isClosed ? .green : .white
            line.lineWidth = 2.5
            addChild(line)
            lineNodes.append(line)

            // Dimension labels
            for i in 0..<points.count {
                let nextIdx = (i + 1) % points.count
                if !isClosed && nextIdx == 0 { break }

                let p1 = points[i]
                let p2 = points[nextIdx]
                let mid = CGPoint(x: (p1.x + p2.x) / 2.0, y: (p1.y + p2.y) / 2.0)
                let distPixels = hypot(p2.x - p1.x, p2.y - p1.y)

                let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
                label.fontSize = 11
                label.fontColor = .yellow
                label.position = CGPoint(x: mid.x, y: mid.y + 10)
                label.text = "\(Int(distPixels * 10)) mm" // 1 px = 10 mm default scale
                addChild(label)
                labelNodes.append(label)
            }
        }
    }

    private func drawGrid() {
        let gridPath = CGMutablePath()
        let step: CGFloat = 40.0

        for x in stride(from: CGFloat(0), to: size.width, by: step) {
            gridPath.move(to: CGPoint(x: x, y: 0))
            gridPath.addLine(to: CGPoint(x: x, y: size.height))
        }

        for y in stride(from: CGFloat(0), to: size.height, by: step) {
            gridPath.move(to: CGPoint(x: 0, y: y))
            gridPath.addLine(to: CGPoint(x: size.width, y: y))
        }

        let gridNode = SKShapeNode(path: gridPath)
        gridNode.strokeColor = SKColor(white: 0.2, alpha: 0.5)
        gridNode.lineWidth = 0.5
        gridNode.zPosition = -10
        addChild(gridNode)
    }
}
