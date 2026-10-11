//
//  SyncClient.swift
//  MagpieField
//
//  HTTP client uploading handoff packages to the Magpie Studio / openPlan3D API (Layer 2, T-705).
//

import Foundation
import MagpieCore

public struct UploadResponse: Codable, Equatable, Sendable {
    public let code: String
    public let reuseUntil: String
    public let packageType: String

    public init(code: String, reuseUntil: String, packageType: String) {
        self.code = code
        self.reuseUntil = reuseUntil
        self.packageType = packageType
    }
}

public struct SyncClient: Sendable {
    public let baseUrl: URL
    public let session: URLSession

    public init(baseUrl: URL, session: URLSession = .shared) {
        self.baseUrl = baseUrl
        self.session = session
    }

    /// Uploads a package ZIP to `/api/handoffs` with Bearer auth
    public func uploadHandoff(
        packageData: Data,
        authToken: String? = nil
    ) async throws -> UploadResponse {
        let endpoint = baseUrl.appendingPathComponent("api/handoffs")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/zip", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-magpie-package")

        if let token = authToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = packageData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw NSError(domain: "SyncClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorText])
        }

        let decoder = JSONDecoder()
        return try decoder.decode(UploadResponse.self, from: data)
    }

    /// Convenience wrapper encoding a MagpiePackage to ZIP and uploading
    public func uploadHandoff(
        package: MagpiePackage,
        authToken: String? = nil
    ) async throws -> UploadResponse {
        let zipData = try PackageBuilder.exportZip(package: package)
        return try await uploadHandoff(packageData: zipData, authToken: authToken)
    }
}
