import XCTest
@testable import Pluck


// MARK: - HTMLAcquisitionTests

final class HTMLAcquisitionTests: XCTestCase {

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }


    // MARK: - Happy path

    func testFetchReturnsHTMLForOK200() async throws {
        let html = "<!doctype html><html><body><h1>Hi</h1></body></html>"
        MockURLProtocol.setResponder { _ in
            .stub(.init(
                statusCode: 200,
                headers: ["Content-Type": "text/html; charset=utf-8"],
                body: Data(html.utf8)
            ))
        }

        let acquisition = HTMLAcquisition(session: .makeMockSession())
        let result = try await acquisition.fetch(url: URL(string: "https://example.com")!)

        XCTAssertEqual(result.html, html)
        XCTAssertEqual(result.encoding, .utf8)
        XCTAssertEqual(result.finalURL.absoluteString, "https://example.com")
        XCTAssertEqual(result.responseHeaders["Content-Type"], "text/html; charset=utf-8")
    }


    // MARK: - Encoding detection

    func testFetchDecodesUTF16FromContentTypeCharset() async throws {
        let html = "<html><body>héllo</body></html>"
        guard
            let body = html.data(using: .utf16)
        else {
            return XCTFail("Could not encode UTF-16 fixture")
        }
        MockURLProtocol.setResponder { _ in
            .stub(.init(
                statusCode: 200,
                headers: ["Content-Type": "text/html; charset=utf-16"],
                body: body
            ))
        }

        let acquisition = HTMLAcquisition(session: .makeMockSession())
        let result = try await acquisition.fetch(url: URL(string: "https://example.com")!)

        XCTAssertEqual(result.html, html)
        XCTAssertEqual(result.encoding, .utf16)
    }

    func testFetchFallsBackToMetaCharsetWhenHeaderSilent() async throws {
        let html = "<!doctype html><html><head><meta charset=\"iso-8859-1\"></head><body>caf\u{00E9}</body></html>"
        guard
            let body = html.data(using: .isoLatin1)
        else {
            return XCTFail("Could not encode ISO-8859-1 fixture")
        }
        MockURLProtocol.setResponder { _ in
            .stub(.init(
                statusCode: 200,
                headers: ["Content-Type": "text/html"],
                body: body
            ))
        }

        let acquisition = HTMLAcquisition(session: .makeMockSession())
        let result = try await acquisition.fetch(url: URL(string: "https://example.com")!)

        XCTAssertEqual(result.encoding, .isoLatin1)
        XCTAssertTrue(result.html.contains("café"))
    }


    // MARK: - Redirects

    func testFetchFollows301AndCapturesFinalURL() async throws {
        let start = URL(string: "https://example.com/old")!
        let target = URL(string: "https://example.com/new")!
        let html = "<html><body>moved</body></html>"

        MockURLProtocol.setResponder { request in
            if request.url == start {
                return .stub(.init(
                    statusCode: 301,
                    headers: ["Location": target.absoluteString],
                    body: Data()
                ))
            }
            return .stub(.init(
                statusCode: 200,
                headers: ["Content-Type": "text/html; charset=utf-8"],
                body: Data(html.utf8)
            ))
        }

        let acquisition = HTMLAcquisition(session: .makeMockSession())
        let result = try await acquisition.fetch(url: start)

        XCTAssertEqual(result.finalURL, target)
        XCTAssertEqual(result.html, html)
    }


    // MARK: - Errors

    func testFetchThrowsHTTPErrorOnNon2xx() async {
        MockURLProtocol.setResponder { _ in
            .stub(.init(statusCode: 404, headers: [:], body: Data()))
        }

        let acquisition = HTMLAcquisition(session: .makeMockSession())
        do {
            _ = try await acquisition.fetch(url: URL(string: "https://example.com/missing")!)
            XCTFail("Expected AcquisitionError.http(404)")
        } catch let error as AcquisitionError {
            XCTAssertEqual(error, .http(404))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchThrowsNotHTMLForJSONContentType() async {
        MockURLProtocol.setResponder { _ in
            .stub(.init(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                body: Data("{}".utf8)
            ))
        }

        let acquisition = HTMLAcquisition(session: .makeMockSession())
        do {
            _ = try await acquisition.fetch(url: URL(string: "https://example.com/data")!)
            XCTFail("Expected AcquisitionError.notHTML")
        } catch let AcquisitionError.notHTML(contentType) {
            XCTAssertEqual(contentType, "application/json")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
