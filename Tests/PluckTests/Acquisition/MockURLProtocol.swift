import Foundation


// MARK: - MockURLProtocol

/// Test-only `URLProtocol` that responds based on a per-request closure.
/// Set `responder` before issuing requests; URLSession's default redirect
/// handling will follow Location headers across multiple stub returns.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {

    struct Stub {
        let statusCode: Int
        let headers: [String: String]
        let body: Data

        init(statusCode: Int = 200, headers: [String: String] = [:], body: Data = Data()) {
            self.statusCode = statusCode
            self.headers = headers
            self.body = body
        }
    }

    enum Outcome {
        case stub(Stub)
        case failure(URLError)
    }

    nonisolated(unsafe) static var responder: (@Sendable (URLRequest) -> Outcome)?

    static func setResponder(_ block: @escaping @Sendable (URLRequest) -> Outcome) {
        responder = block
    }

    static func reset() {
        responder = nil
    }


    // MARK: - URLProtocol overrides

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard
            let responder = MockURLProtocol.responder,
            let url = request.url
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        switch responder(request) {
        case .stub(let stub):
            let response = HTTPURLResponse(
                url: url,
                statusCode: stub.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: stub.headers
            )!

            if (300..<400).contains(stub.statusCode),
               let location = stub.headers.first(where: { $0.key.lowercased() == "location" })?.value,
               let target = URL(string: location, relativeTo: url) {
                let newRequest = URLRequest(url: target.absoluteURL)
                client?.urlProtocol(self, wasRedirectedTo: newRequest, redirectResponse: response)
                client?.urlProtocolDidFinishLoading(self)
                return
            }

            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.body)
            client?.urlProtocolDidFinishLoading(self)

        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}


// MARK: - URLSession factory

extension URLSession {
    static func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
