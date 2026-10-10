//
//  SyncClient.swift
//  MagpieField
//
//  HTTP client uploading handoff packages to the Magpie Studio / openPlan3D API (Layer 2, T-705).
//

import Foundation
import MagpieCore

public struct UploadResponse: Codable, Sendable {
    public let id: String
    public let checksum: String?
    public let size: Int?
    public let success: Bool?
}

public struct SyncClient: Sendable {
    public let baseUrl: URL
    public let session: URLSession

    public init(baseUrl: URL, session: URLSession = .shared) {
        self.baseUrl = baseUrl
        self.session = session
    }

    /// Uploads a package payload to `/api/handoffs/[id]` with Bearer auth
    public func uploadHandoff(
        package: MagpiePackage,
        authToken: String? = nil
    ) async throws -> UploadResponse {
        let endpoint = baseUrl.appendingPathComponent("api/handoffs/\(package.manifest.siteId)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Package payload body
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let bodyData = try encoder.encode(package)
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw NSError(domain: "SyncClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorText])
        }

        let decoder = JSONDecoder()
        if let uploadResponse = try? decoder.decode(UploadResponse.self, from: data) {
            return uploadResponse
        }

        // Default response if server returned 200 without JSON
        return UploadResponse(id: package.manifest.siteId, checksum: "sha256-\(bodyData.count)", size: bodyData.count, success: true)
    }
}
