//
//  RoomCaptureViewController.swift
//  MagpieField
//
//  Direct RoomPlan capture controller with live guidance, coverage check, and photo capture (Layer 3, T-101).
//

import UIKit
import RoomPlan
import ARKit
import MagpieCore

public protocol RoomCaptureViewControllerDelegate: AnyObject {
    func roomCaptureDidFinish(with room: CapturedRoom, photos: [PhotoCaptureManager.CapturedPhoto])
    func roomCaptureDidCancel()
}

@MainActor
public final class RoomCaptureViewController: UIViewController, RoomCaptureViewDelegate, RoomCaptureSessionDelegate {

    public weak var delegate: RoomCaptureViewControllerDelegate?

    private var roomCaptureView: RoomCaptureView!
    private var roomCaptureConfig = RoomCaptureSession.Configuration()
    private let photoManager = PhotoCaptureManager()
    private let coverageAnalyzer = CoverageAnalyzer()

    private var isScanning = false
    private var finalRoom: CapturedRoom?

    // UI Elements
    private let instructionBanner = UILabel()
    private let speedWarningBanner = UILabel()
    private let statsLabel = UILabel()
    private let stopButton = UIButton(type: .system)
    private let capturePhotoButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let photoBadge = UILabel()

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupCaptureView()
        setupOverlayUI()
        HapticFeedbackManager.shared.prepareGenerators()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startScanning()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    private func setupCaptureView() {
        roomCaptureView = RoomCaptureView(frame: view.bounds)
        roomCaptureView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        roomCaptureView.captureSession.delegate = self
        roomCaptureView.delegate = self
        view.addSubview(roomCaptureView)
    }

    private func setupOverlayUI() {
        // 1. Instruction Banner
        instructionBanner.translatesAutoresizingMaskIntoConstraints = false
        instructionBanner.text = "Slowly point camera at walls, doors, and cabinets"
        instructionBanner.textColor = .white
        instructionBanner.font = .systemFont(ofSize: 15, weight: .semibold)
        instructionBanner.textAlignment = .center
        instructionBanner.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        instructionBanner.layer.cornerRadius = 10
        instructionBanner.clipsToBounds = true
        view.addSubview(instructionBanner)

        // 2. Speed / Lighting Warning Banner
        speedWarningBanner.translatesAutoresizingMaskIntoConstraints = false
        speedWarningBanner.textColor = .white
        speedWarningBanner.font = .systemFont(ofSize: 14, weight: .bold)
        speedWarningBanner.textAlignment = .center
        speedWarningBanner.backgroundColor = UIColor.systemRed.withAlphaComponent(0.85)
        speedWarningBanner.layer.cornerRadius = 8
        speedWarningBanner.clipsToBounds = true
        speedWarningBanner.isHidden = true
        view.addSubview(speedWarningBanner)

        // 3. Stats HUD
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        statsLabel.text = "Walls: 0 | Objects: 0"
        statsLabel.textColor = .white
        statsLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        statsLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        statsLabel.layer.cornerRadius = 6
        statsLabel.clipsToBounds = true
        statsLabel.textAlignment = .center
        view.addSubview(statsLabel)

        // 4. Action Buttons
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.setTitle("Finish Scan", for: .normal)
        stopButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        stopButton.backgroundColor = .systemGreen
        stopButton.tintColor = .white
        stopButton.layer.cornerRadius = 24
        stopButton.addTarget(self, action: #selector(didTapDone), for: .touchUpInside)
        view.addSubview(stopButton)

        capturePhotoButton.translatesAutoresizingMaskIntoConstraints = false
        capturePhotoButton.setImage(UIImage(systemName: "camera.fill"), for: .normal)
        capturePhotoButton.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        capturePhotoButton.tintColor = .white
        capturePhotoButton.layer.cornerRadius = 25
        capturePhotoButton.addTarget(self, action: #selector(didTapTakePhoto), for: .touchUpInside)
        view.addSubview(capturePhotoButton)

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.tintColor = .white
        cancelButton.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)
        view.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            instructionBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            instructionBanner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionBanner.heightAnchor.constraint(equalToConstant: 40),
            instructionBanner.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),

            speedWarningBanner.topAnchor.constraint(equalTo: instructionBanner.bottomAnchor, constant: 8),
            speedWarningBanner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            speedWarningBanner.heightAnchor.constraint(equalToConstant: 34),
            speedWarningBanner.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),

            statsLabel.topAnchor.constraint(equalTo: speedWarningBanner.bottomAnchor, constant: 8),
            statsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statsLabel.widthAnchor.constraint(equalToConstant: 220),
            statsLabel.heightAnchor.constraint(equalToConstant: 28),

            stopButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            stopButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stopButton.widthAnchor.constraint(equalToConstant: 180),
            stopButton.heightAnchor.constraint(equalToConstant: 48),

            capturePhotoButton.centerYAnchor.constraint(equalTo: stopButton.centerYAnchor),
            capturePhotoButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            capturePhotoButton.widthAnchor.constraint(equalToConstant: 50),
            capturePhotoButton.heightAnchor.constraint(equalToConstant: 50),

            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16)
        ])
    }

    public func startScanning() {
        guard !isScanning else { return }
        isScanning = true
        coverageAnalyzer.reset()
        roomCaptureView.captureSession.run(configuration: roomCaptureConfig)
    }

    public func stopScanning() {
        guard isScanning else { return }
        isScanning = false
        roomCaptureView.captureSession.stop()
    }

    @objc private func didTapDone() {
        HapticFeedbackManager.shared.scanComplete()
        stopScanning()
    }

    @objc private func didTapCancel() {
        stopScanning()
        delegate?.roomCaptureDidCancel()
    }

    @objc private func didTapTakePhoto() {
        // Capture screenshot of current view hierarchy
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, 0.0)
        view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        if let image = image {
            HapticFeedbackManager.shared.objectDetected()
            _ = photoManager.addPhoto(image)
            instructionBanner.text = "📸 Photo captured (\(photoManager.photoCount))"
        }
    }

    // MARK: - RoomCaptureSessionDelegate

    public func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        let wallsCount = room.walls.count
        let objectsCount = room.objects.count
        statsLabel.text = "Walls: \(wallsCount) | Objects: \(objectsCount)"

        if let frame = session.arSession.currentFrame {
            let status = coverageAnalyzer.analyzeFrame(frame)
            if let warning = status.warningMessage {
                speedWarningBanner.text = "⚠️ \(warning)"
                speedWarningBanner.isHidden = false
            } else {
                speedWarningBanner.isHidden = true
            }
        }
    }

    public func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
        if let error = error {
            speedWarningBanner.text = "Capture error: \(error.localizedDescription)"
            speedWarningBanner.isHidden = false
        }
    }

    // MARK: - RoomCaptureViewDelegate

    public func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        return true
    }

    public func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        self.finalRoom = processedResult
        if let error = error {
            print("Processing completed with error: \(error)")
        }
        delegate?.roomCaptureDidFinish(with: processedResult, photos: photoManager.photos)
    }
}
