//
//  SyncClientTests.swift
//  MagpieFieldTests
//
//  Tests for SyncClient using a custom URLProtocol mock.
//

import XCTest
import MagpieCore
@testable import MagpieField

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("Handler is not set.")
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class SyncClientTests: XCTestCase {
    var session: URLSession!
    let testBaseUrl = URL(string: "https://magpie.example.com")!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: configuration)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        session = nil
        super.tearDown()
    }

    func testUploadSucceedsWithValidServerResponse() async throws {
        let expectedCode = "TESTCODE"
        let responseJson = """
        {
            "code": "\(expectedCode)",
            "reuseUntil": "2026-10-12T12:00:00.000Z",
            "packageType": "magpie-package"
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/handoffs")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/zip")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-magpie-package"), "true")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 201,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, responseJson)
        }

        let client = SyncClient(baseUrl: testBaseUrl, session: session)
        let sampleData = "fake-zip-data".data(using: .utf8)!
        let result = try await client.uploadHandoff(packageData: sampleData, authToken: "sample-token")

        XCTAssertEqual(result.code, expectedCode)
        XCTAssertEqual(result.packageType, "magpie-package")
    }

    func testUploadFailsOnNon2xxResponse() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 422,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, "Invalid package archive".data(using: .utf8)!)
        }

        let client = SyncClient(baseUrl: testBaseUrl, session: session)
        let sampleData = "bad-data".data(using: .utf8)!

        do {
            _ = try await client.uploadHandoff(packageData: sampleData)
            XCTFail("Expected uploadHandoff to throw on 422")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.code, 422)
        }
    }

    func testUploadFailsOnUnparseableResponse() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, "not-json".data(using: .utf8)!)
        }

        let client = SyncClient(baseUrl: testBaseUrl, session: session)
        let sampleData = "sample".data(using: .utf8)!

        do {
            _ = try await client.uploadHandoff(packageData: sampleData)
            XCTFail("Expected uploadHandoff to throw on unparseable JSON (no fabricated success)")
        } catch {
            // Success: client throws instead of fabricating a response
            XCTAssertTrue(error is DecodingError || (error as NSError).domain == NSCocoaErrorDomain)
        }
    }
}
