//
//  LibraryView.swift
//  MagpieField
//
//  Saved site capture library view.
//  Displays local site capture packages, sync status indicators, upload retry actions, and package export.
//

import SwiftUI
import MagpieCore

public struct LibraryView: View {
    @State private var records: [SiteCaptureRecord] = []
    @State private var searchText: String = ""
    @State private var selectedRecord: SiteCaptureRecord? = nil
    @State private var shareURL: URL? = nil
    @State private var showShareSheet: Bool = false
    @State private var isRefreshing: Bool = false

    public init() {}

    private var filteredRecords: [SiteCaptureRecord] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return records
        }
        let query = searchText.lowercased()
        return records.filter {
            $0.siteId.lowercased().contains(query) ||
            $0.roomLabel.lowercased().contains(query) ||
            $0.workerName.lowercased().contains(query)
        }
    }

    public var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(filteredRecords) { record in
                            SiteRecordRow(
                                record: record,
                                onRetrySync: { retrySync(for: record) },
                                onShare: { share(record: record) }
                            )
                        }
                        .onDelete(perform: deleteRecords)
                    }
                    .listStyle(.insetGrouped)
                    .searchable(text: $searchText, prompt: "Search site ID, room, or worker...")
                }
            }
            .navigationTitle("Site Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        SiteSetupView()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("New Capture")
                        }
                        .fontWeight(.semibold)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        loadRecords()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                loadRecords()
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Site Captures Saved")
                .font(.headline)
            Text("Completed kitchen scans and verified tape measurements will appear here for sync and review.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func loadRecords() {
        records = RoomStorageManager.shared.fetchAllSiteRecords()
    }

    private func deleteRecords(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { filteredRecords[$0] }
        for item in itemsToDelete {
            RoomStorageManager.shared.deleteSiteRecord(id: item.id)
        }
        loadRecords()
    }

    private func retrySync(for record: SiteCaptureRecord) {
        var updated = record
        updated.syncStatus = .uploading
        updated.attemptCount += 1
        RoomStorageManager.shared.saveSiteRecord(updated)
        loadRecords()

        SyncQueue.shared.enqueue(updated) { success, url, error in
            DispatchQueue.main.async {
                loadRecords()
            }
        }
    }

    private func share(record: SiteCaptureRecord) {
        guard let data = record.packageData else { return }
        let tempDir = FileManager.default.temporaryDirectory
        let safeName = "magpie-\(record.siteId)-\(record.id.prefix(6)).zip"
        let url = tempDir.appendingPathComponent(safeName)
        try? data.write(to: url)
        self.shareURL = url
        self.showShareSheet = true
    }
}

// MARK: - SiteRecordRow

private struct SiteRecordRow: View {
    let record: SiteCaptureRecord
    let onRetrySync: () -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.roomLabel)
                        .font(.headline)
                    Text("Site: \(record.siteId) • By \(record.workerName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                statusBadge(for: record.syncStatus)
            }

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                    Text(formatDate(record.createdAt))
                }
                .font(.caption2)
                .foregroundColor(.secondary)

                Spacer()

                if record.syncStatus == .failed || record.syncStatus == .pending {
                    Button {
                        onRetrySync()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Retry Sync")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                    }
                }

                Button {
                    onShare()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func statusBadge(for status: SiteCaptureRecord.SyncStatus) -> some View {
        let (title, color, icon): (String, Color, String) = {
            switch status {
            case .pending:
                return ("Pending", .orange, "clock")
            case .uploading:
                return ("Syncing", .blue, "arrow.triangle.2.circlepath")
            case .uploaded:
                return ("Synced", .green, "checkmark.circle.fill")
            case .confirmed:
                return ("Confirmed", .purple, "checkmark.seal.fill")
            case .failed:
                return ("Failed", .red, "exclamationmark.circle.fill")
            }
        }()

        return HStack(spacing: 4) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.caption2)
        .fontWeight(.semibold)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.12))
        .foregroundColor(color)
        .cornerRadius(4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
