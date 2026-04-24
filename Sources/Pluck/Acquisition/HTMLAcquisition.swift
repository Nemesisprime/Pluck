import Foundation


// MARK: - HTMLAcquisition

public struct HTMLAcquisition: Sendable {

    private let session: URLSession
    private let timeout: TimeInterval


    // MARK: - Init

    public init(session: URLSession = .shared, timeout: TimeInterval = 15) {
        self.session = session
        self.timeout = timeout
    }


    // MARK: - Fetch

    public func fetch(url: URL) async throws -> AcquisitionResult {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw AcquisitionError.timeout
        }

        guard
            let http = response as? HTTPURLResponse
        else {
            throw AcquisitionError.invalidResponse
        }

        guard
            (200..<300).contains(http.statusCode)
        else {
            throw AcquisitionError.http(http.statusCode)
        }

        let contentType = HTMLAcquisition.headerValue(http, "Content-Type")
        if let contentType, !HTMLAcquisition.isHTML(contentType: contentType) {
            throw AcquisitionError.notHTML(contentType)
        }

        let encoding = HTMLAcquisition.detectEncoding(
            contentType: contentType,
            data: data
        )

        guard
            let html = String(data: data, encoding: encoding)
        else {
            throw AcquisitionError.decoding
        }

        let headers = HTMLAcquisition.normalizeHeaders(http.allHeaderFields)
        let finalURL = http.url ?? url

        return AcquisitionResult(
            html: html,
            finalURL: finalURL,
            responseHeaders: headers,
            encoding: encoding
        )
    }
}


// MARK: - Helpers

private extension HTMLAcquisition {

    static func headerValue(_ response: HTTPURLResponse, _ name: String) -> String? {
        if #available(iOS 13.0, macOS 10.15, *) {
            return response.value(forHTTPHeaderField: name)
        }
        let lowered = name.lowercased()
        for (key, value) in response.allHeaderFields {
            if let keyString = key as? String, keyString.lowercased() == lowered {
                return value as? String
            }
        }
        return nil
    }

    static func normalizeHeaders(_ raw: [AnyHashable: Any]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in raw {
            if let key = key as? String, let value = value as? String {
                result[key] = value
            }
        }
        return result
    }

    static func isHTML(contentType: String) -> Bool {
        let lowered = contentType.lowercased()
        return lowered.contains("text/html")
            || lowered.contains("application/xhtml")
            || lowered.contains("application/xml")
    }

    static func detectEncoding(contentType: String?, data: Data) -> String.Encoding {
        if let charset = contentType.flatMap(parseCharset),
           let encoding = encoding(forIANAName: charset) {
            return encoding
        }
        if let metaCharset = sniffMetaCharset(data: data),
           let encoding = encoding(forIANAName: metaCharset) {
            return encoding
        }
        return .utf8
    }

    static func parseCharset(_ contentType: String) -> String? {
        let parts = contentType.split(separator: ";")
        for raw in parts {
            let part = raw.trimmingCharacters(in: .whitespaces)
            if part.lowercased().hasPrefix("charset=") {
                let value = part.dropFirst("charset=".count)
                return value
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        }
        return nil
    }

    static func encoding(forIANAName name: String) -> String.Encoding? {
        let cf = CFStringConvertIANACharSetNameToEncoding(name as CFString)
        guard
            cf != kCFStringEncodingInvalidId
        else {
            return nil
        }
        let nsValue = CFStringConvertEncodingToNSStringEncoding(cf)
        return String.Encoding(rawValue: nsValue)
    }

    /// Best-effort sniff for `<meta charset="...">` or `<meta http-equiv="Content-Type" content="...; charset=...">`
    /// in the first 1024 bytes. Uses ISO-Latin-1 for the sniff so bytes >= 128 don't fail decode
    /// (every byte is one Latin-1 codepoint); the actual page is re-decoded with the discovered encoding.
    static func sniffMetaCharset(data: Data) -> String? {
        let prefix = data.prefix(1024)
        guard
            let raw = String(data: prefix, encoding: .isoLatin1)
        else {
            return nil
        }
        let lowered = raw.lowercased()

        if let range = lowered.range(of: "charset=") {
            let after = lowered[range.upperBound...]
            let terminators = CharacterSet(charactersIn: " />\t\n\r;")
            var charset = ""
            for ch in after {
                if ch == "\"" || ch == "'" {
                    if charset.isEmpty {
                        continue
                    }
                    break
                }
                if let scalar = ch.unicodeScalars.first, terminators.contains(scalar) {
                    break
                }
                charset.append(ch)
            }
            if !charset.isEmpty {
                return charset
            }
        }
        return nil
    }
}
