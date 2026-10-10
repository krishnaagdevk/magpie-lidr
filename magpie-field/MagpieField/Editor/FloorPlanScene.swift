//
//  FloorPlanScene.swift
//  MagpieField
//
//  Interactive 2D SpriteKit Scene rendering and editing the single source of truth: EditedPlan (Layer 3, T-302).
//

import SpriteKit
import UIKit
import MagpieCore

public final class FloorPlanScene: SKScene {
    public let viewModel: FloorPlanViewModel
    private var cameraNode = SKCameraNode()

    public init(viewModel: FloorPlanViewModel) {
        self.viewModel = viewModel
        super.init(size: DrawParameters.floorPlanSize)

        self.scaleMode = .aspectFill
        self.anchorPoint = DrawParameters.floorPlanAnchorPoint
        self.backgroundColor = DrawParameters.floorPlanBackgroundColor

        setupCamera()
        rebuildScene()
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCamera() {
        cameraNode = SKCameraNode()
        cameraNode.position = .zero
        cameraNode.setScale(1.0)
        addChild(cameraNode)
        self.camera = cameraNode
    }

    public override func didMove(to view: SKView) {
        super.didMove(to: view)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)
    }

    public func rebuildScene() {
        // Clear existing nodes except camera
        children.filter { $0 != cameraNode }.forEach { $0.removeFromParent() }

        let plan = viewModel.editedPlan

        // 1. Draw Walls
        for wall in plan.walls {
            let cx = CGFloat(wall.transform.m[12]) * DrawParameters.scaleFactor
            let cy = CGFloat(wall.transform.m[14]) * DrawParameters.scaleFactor
            let heading = CGFloat(wall.transform.headingRadians)

            let surface = FloorPlanSurface(
                id: wall.id,
                category: .wall,
                lengthM: wall.dimensions.x,
                heightM: wall.dimensions.y,
                thicknessM: wall.dimensions.z,
                position: CGPoint(x: cx, y: cy),
                rotationZ: heading
            )
            addChild(surface)
        }

        // 2. Draw Doors & Windows
        for door in plan.doors {
            let cx = CGFloat(door.transform.m[12]) * DrawParameters.scaleFactor
            let cy = CGFloat(door.transform.m[14]) * DrawParameters.scaleFactor
            let heading = CGFloat(door.transform.headingRadians)

            let surface = FloorPlanSurface(
                id: door.id,
                category: .door,
                lengthM: door.dimensions.x,
                heightM: door.dimensions.y,
                thicknessM: door.dimensions.z,
                position: CGPoint(x: cx, y: cy),
                rotationZ: heading
            )
            addChild(surface)
        }

        for window in plan.windows {
            let cx = CGFloat(window.transform.m[12]) * DrawParameters.scaleFactor
            let cy = CGFloat(window.transform.m[14]) * DrawParameters.scaleFactor
            let heading = CGFloat(window.transform.headingRadians)

            let surface = FloorPlanSurface(
                id: window.id,
                category: .window,
                lengthM: window.dimensions.x,
                heightM: window.dimensions.y,
                thicknessM: window.dimensions.z,
                position: CGPoint(x: cx, y: cy),
                rotationZ: heading
            )
            addChild(surface)
        }

        // 3. Draw Objects / Cabinets
        for obj in plan.objects {
            let cx = CGFloat(obj.transform.m[12]) * DrawParameters.scaleFactor
            let cy = CGFloat(obj.transform.m[14]) * DrawParameters.scaleFactor
            let heading = CGFloat(obj.transform.headingRadians)

            let objectNode = FloorPlanObject(
                id: obj.id,
                category: obj.category,
                dimensions: obj.dimensions,
                position: CGPoint(x: cx, y: cy),
                rotationZ: heading
            )
            addChild(objectNode)
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let view = view else { return }
        let locationInView = gesture.location(in: view)
        let locationInScene = convertPoint(fromView: locationInView)

        let touchedNodes = nodes(at: locationInScene)

        if let surface = touchedNodes.compactMap({ $0 as? FloorPlanSurface }).first {
            viewModel.selectedSurface?.deselect()
            viewModel.selectedObject?.deselect()
            surface.select()
            viewModel.selectedSurface = surface
            viewModel.selectedObject = nil
            viewModel.isEditingWallLength = true
            HapticFeedbackManager.shared.objectDetected()
        } else if let objectNode = touchedNodes.compactMap({ $0 as? FloorPlanObject }).first {
            viewModel.selectedSurface?.deselect()
            viewModel.selectedObject?.deselect()
            objectNode.select()
            viewModel.selectedObject = objectNode
            viewModel.selectedSurface = nil
            viewModel.isTaggingKitchen = true
            HapticFeedbackManager.shared.objectDetected()
        } else {
            viewModel.selectedSurface?.deselect()
            viewModel.selectedObject?.deselect()
            viewModel.selectedSurface = nil
            viewModel.selectedObject = nil
            viewModel.isEditingWallLength = false
            viewModel.isTaggingKitchen = false
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view = view else { return }
        let translation = gesture.translation(in: view)
        let cameraScale = cameraNode.xScale

        cameraNode.position = CGPoint(
            x: cameraNode.position.x - translation.x * cameraScale,
            y: cameraNode.position.y + translation.y * cameraScale
        )
        gesture.setTranslation(.zero, in: view)
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .changed {
            let newScale = cameraNode.xScale / gesture.scale
            let clampedScale = max(0.2, min(5.0, newScale))
            cameraNode.setScale(clampedScale)
            gesture.scale = 1.0
        }
    }
}
