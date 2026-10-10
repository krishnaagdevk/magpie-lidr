//
//  ScanFlowView.swift
//  MagpieField
//
//  SwiftUI wrapper hosting RoomCaptureViewController during active scanning (Layer 3).
//

import SwiftUI
import RoomPlan
import MagpieCore

public struct ScanFlowView: View {
    public let siteId: String
    public let workerName: String
    public let roomLabel: String

    @Environment(\.dismiss) private var dismiss
    @State private var capturedRoom: CapturedRoom?
    @State private var capturedPhotos: [PhotoCaptureManager.CapturedPhoto] = []
    @State private var isNavigatingToReview: Bool = false

    public var body: some View {
        ZStack {
            RoomCaptureRepresentable(
                onFinish: { room, photos in
                    self.capturedRoom = room
                    self.capturedPhotos = photos
                    self.isNavigatingToReview = true
                },
                onCancel: {
                    dismiss()
                }
            )
            .ignoresSafeArea()
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $isNavigatingToReview) {
            if let room = capturedRoom {
                ReviewFlowView(
                    siteId: siteId,
                    workerName: workerName,
                    roomLabel: roomLabel,
                    rawRoom: room,
                    photos: capturedPhotos
                )
            }
        }
    }
}

struct RoomCaptureRepresentable: UIViewControllerRepresentable {
    let onFinish: (CapturedRoom, [PhotoCaptureManager.CapturedPhoto]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> RoomCaptureViewController {
        let vc = RoomCaptureViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: RoomCaptureViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish, onCancel: onCancel)
    }

    final class Coordinator: RoomCaptureViewControllerDelegate {
        let onFinish: (CapturedRoom, [PhotoCaptureManager.CapturedPhoto]) -> Void
        let onCancel: () -> Void

        init(onFinish: @escaping (CapturedRoom, [PhotoCaptureManager.CapturedPhoto]) -> Void, onCancel: @escaping () -> Void) {
            self.onFinish = onFinish
            self.onCancel = onCancel
        }

        func roomCaptureDidFinish(with room: CapturedRoom, photos: [PhotoCaptureManager.CapturedPhoto]) {
            onFinish(room, photos)
        }

        func roomCaptureDidCancel() {
            onCancel()
        }
    }
}
