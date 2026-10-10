//
//  ExportFlowView.swift
//  MagpieField
//
//  Phase 6: Export & Packaging flow view.
//  Builds the MagpiePackage ZIP (manifest, handoff v1 plan.json, measurements.json, photos),
//  provides local file sharing, and dispatches background cloud upload to Magpie Studio.
//

import SwiftUI
import MagpieCore

public struct ExportFlowView: View {
    public let plan: EditedPlan
    public let measurements: [Measurement]
    public let validation: ValidationBlock
    public let siteId: String
    public let workerName: String
    public let roomLabel: String
    public let photos: [PhotoCaptureManager.CapturedPhoto]

    @State private var isBuildingPackage: Bool = false
    @State private var packageData: Data? = nil
    @State private var packageURL: URL? = nil
    @State private var isUploading: Bool = false
    @State private var uploadProgress: Float = 0.0
    @State private var uploadSuccess: Bool = false
    @State private var uploadError: String? = nil
    @State private var showShareSheet: Bool = false
    @State private var showLocalSuccessAlert: Bool = false
    @State private var directStudioURL: String? = nil

    @Environment(\.dismiss) private var dismiss

    public init(
        plan: EditedPlan,
        measurements: [Measurement],
        validation: ValidationBlock,
        siteId: String,
        workerName: String,
        roomLabel: String,
        photos: [PhotoCaptureManager.CapturedPhoto] = []
    ) {
        self.plan = plan
        self.measurements = measurements
        self.validation = validation
        self.siteId = siteId
        self.workerName = workerName
        self.roomLabel = roomLabel
        self.photos = photos
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary Card
                summaryCard

                // Package Contents Breakdown
                packageContentsCard

                // Export & Sharing Options
                actionsCard

                // Cloud Sync Section
                cloudSyncCard
            }
            .padding()
        }
        .navigationTitle("Package & Export")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            buildPackageIfNeeded()
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = packageURL {
                ShareSheet(activityItems: [url])
            }
        }
        .alert("Capture Saved", isPresented: $showLocalSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Site capture package has been securely archived on this device.")
        }
    }

    // MARK: - Subviews

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(roomLabel)
                        .font(.headline)
                    Text("Site ID: \(siteId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(validation.gateResult.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(validation.gateResult == "pass" ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                        .foregroundColor(validation.gateResult == "pass" ? .green : .orange)
                        .cornerRadius(6)
                    Text("By \(workerName)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            HStack(spacing: 16) {
                statItem(title: "Walls", value: "\(plan.walls.count)")
                statItem(title: "Doors", value: "\(plan.doors.count)")
                statItem(title: "Windows", value: "\(plan.windows.count)")
                statItem(title: "Verified", value: "\(validation.criticalWithinTolerance)/\(validation.criticalCount)")
                statItem(title: "Photos", value: "\(photos.count)")
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var packageContentsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PACKAGE ARTIFACTS")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                fileRow(name: "manifest.json", detail: "Metadata, site tags, validation signature", icon: "doc.plaintext")
                fileRow(name: "plan.json", detail: "Handoff v1 CAD geometry", icon: "square.2.layers.3d")
                fileRow(name: "measurements.json", detail: "\(measurements.count) itemized dimensions & tolerances", icon: "ruler")
                if !photos.isEmpty {
                    fileRow(name: "photos/", detail: "\(photos.count) field verification photos", icon: "photo.stack")
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func fileRow(name: String, detail: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundColor(.green)
        }
    }

    private var actionsCard: some View {
        VStack(spacing: 12) {
            Button {
                showShareSheet = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share / Export Package (.zip)")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(packageURL == nil)

            Button {
                saveToLocalStorage()
            } label: {
                HStack {
                    Image(systemName: "internaldrive")
                    Text("Save to On-Device Library")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.tertiarySystemBackground))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }
        }
    }

    private var cloudSyncCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CLOUD SYNC")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)

            if uploadSuccess {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "icloud.and.arrow.up.fill")
                            .foregroundColor(.green)
                        Text("Uploaded to Magpie Studio")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                    }

                    if let studioURL = directStudioURL {
                        Link(destination: URL(string: studioURL)!) {
                            HStack {
                                Text("Open in Web CAD Studio")
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                        }
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else if isUploading {
                VStack(spacing: 6) {
                    ProgressView(value: uploadProgress)
                    Text("Dispatching encrypted package...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                Button {
                    startCloudUpload()
                } label: {
                    HStack {
                        Image(systemName: "icloud.and.arrow.up")
                        Text("Upload to Magpie Studio")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(12)
                }
            }

            if let err = uploadError {
                Text("Sync error: \(err)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Logic & Actions

    private func buildPackageIfNeeded() {
        guard packageURL == nil else { return }
        isBuildingPackage = true

        DispatchQueue.global(qos: .userInitiated).async {
            let metadata = CaptureMetadata(
                siteId: siteId,
                workerName: workerName,
                roomLabel: roomLabel,
                scannedAt: ISO8601DateFormatter().string(from: Date()),
                validation: validation
            )

            let photoDataMap = Dictionary(uniqueKeysWithValues: photos.map { ("photos/\($0.id).jpg", $0.jpegData) })

            if let zipData = PackageBuilder.buildPackage(
                plan: plan,
                measurements: measurements,
                metadata: metadata,
                photos: photoDataMap
            ) {
                let tempDir = FileManager.default.temporaryDirectory
                let safeSite = metadata.sanitizedSiteId()
                let fileName = "magpie-\(safeSite)-\(Int(Date().timeIntervalSince1970)).zip"
                let fileURL = tempDir.appendingPathComponent(fileName)

                try? zipData.write(to: fileURL)

                DispatchQueue.main.async {
                    self.packageData = zipData
                    self.packageURL = fileURL
                    self.isBuildingPackage = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isBuildingPackage = false
                }
            }
        }
    }

    private func saveToLocalStorage() {
        guard let data = packageData else { return }
        let record = SiteCaptureRecord(
            id: UUID().uuidString,
            siteId: siteId,
            workerName: workerName,
            roomLabel: roomLabel,
            syncStatus: .pending,
            packageData: data
        )

        RoomStorageManager.shared.saveSiteRecord(record)
        showLocalSuccessAlert = true
    }

    private func startCloudUpload() {
        guard let data = packageData else { return }
        isUploading = true
        uploadProgress = 0.2
        uploadError = nil

        let record = SiteCaptureRecord(
            id: UUID().uuidString,
            siteId: siteId,
            workerName: workerName,
            roomLabel: roomLabel,
            syncStatus: .uploading,
            packageData: data
        )

        SyncQueue.shared.enqueue(record) { success, urlString, error in
            DispatchQueue.main.async {
                self.isUploading = false
                if success {
                    self.uploadSuccess = true
                    self.directStudioURL = urlString
                } else {
                    self.uploadError = error ?? "Upload failed. Enqueued for retry."
                }
            }
        }
    }
}

// MARK: - ShareSheet Helper

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
