//
//  FloorPlanSceneView.swift
//  MagpieField
//
//  SwiftUI UIViewRepresentable wrapper hosting the SpriteKit FloorPlanScene (Layer 3).
//

import SwiftUI
import SpriteKit

public struct FloorPlanSceneView: UIViewRepresentable {
    @ObservedObject public var viewModel: FloorPlanViewModel

    public init(viewModel: FloorPlanViewModel) {
        self.viewModel = viewModel
    }

    public func makeUIView(context: Context) -> SKView {
        let skView = SKView()
        skView.showsFPS = false
        skView.showsNodeCount = false
        skView.ignoresSiblingOrder = true

        let scene = FloorPlanScene(viewModel: viewModel)
        skView.presentScene(scene)
        context.coordinator.scene = scene

        return skView
    }

    public func updateUIView(_ uiView: SKView, context: Context) {
        context.coordinator.scene?.rebuildScene()
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public final class Coordinator {
        var scene: FloorPlanScene?
    }
}
