import Foundation


// MARK: - AcquisitionResult

public struct AcquisitionResult: Sendable, Equatable {

    public let html: String
    public let finalURL: URL
    public let responseHeaders: [String: String]
    public let encoding: String.Encoding


    // MARK: - Init

    public init(
        html: String,
        finalURL: URL,
        responseHeaders: [String: String],
        encoding: String.Encoding
    ) {
        self.html = html
        self.finalURL = finalURL
        self.responseHeaders = responseHeaders
        self.encoding = encoding
    }
}


// MARK: - AcquisitionError

public enum AcquisitionError: Error, Equatable, Sendable {
    case http(Int)
    case notHTML(String?)
    case decoding
    case timeout
    case invalidResponse
}
