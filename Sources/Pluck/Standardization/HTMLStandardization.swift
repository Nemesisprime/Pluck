import Foundation
import SwiftSoup


// MARK: - HTMLStandardization

/// HTML cleanup utilities used by `ContentExtractor` and `ImageExtractor` to
/// produce a stable, portable element tree before downstream processing.
///
/// Run order: `cleanup` → `resolveSrcset` → `absolutizeURLs` → `normalizeHeadings`.
enum HTMLStandardization {

    // MARK: - Cleanup

    /// Removes scripts, styles, comments, and zero-byte tracking pixels.
    static func cleanup(_ element: SwiftSoup.Element) throws {
        for selector in ["script", "style", "noscript", "iframe[src*=tracking]"] {
            for node in try element.select(selector).array() {
                try node.remove()
            }
        }

        for image in try element.select("img").array() {
            let width = Int(try image.attr("width")) ?? -1
            let height = Int(try image.attr("height")) ?? -1
            if width == 1 || height == 1 {
                try image.remove()
            }
        }

        try removeComments(element)
    }


    // MARK: - srcset

    /// Picks the largest candidate from each `srcset` and writes it back to `src`,
    /// so downstream consumers don't need to re-parse the responsive-image syntax.
    static func resolveSrcset(in element: SwiftSoup.Element) throws {
        for image in try element.select("img[srcset]").array() {
            let srcset = try image.attr("srcset")
            if let best = bestCandidate(fromSrcset: srcset) {
                try image.attr("src", best)
                try image.removeAttr("srcset")
            }
        }
    }


    // MARK: - URLs

    /// Rewrites every `href`/`src` to an absolute URL relative to `baseURL`.
    static func absolutizeURLs(in element: SwiftSoup.Element, baseURL: URL) throws {
        for (attribute, selector) in [("href", "a[href]"), ("src", "img[src]")] {
            for node in try element.select(selector).array() {
                let raw = try node.attr(attribute)
                if raw.isEmpty {
                    continue
                }
                if let absolute = URL(string: raw, relativeTo: baseURL)?.absoluteURL {
                    try node.attr(attribute, absolute.absoluteString)
                }
            }
        }
    }


    // MARK: - Headings

    /// If a content fragment contains more than one `<h1>`, demotes them all by one
    /// level so the document outline starts cleanly under the parent's title.
    static func normalizeHeadings(in element: SwiftSoup.Element) throws {
        let h1s = try element.select("h1")
        guard
            h1s.size() > 1
        else {
            return
        }
        for heading in h1s.array() {
            try heading.tagName("h2")
        }
    }


    // MARK: - Comment removal

    private static func removeComments(_ element: SwiftSoup.Element) throws {
        var stack: [SwiftSoup.Node] = [element]
        while let node = stack.popLast() {
            for child in node.getChildNodes() {
                if child is Comment {
                    try child.remove()
                } else {
                    stack.append(child)
                }
            }
        }
    }


    // MARK: - srcset parsing

    private static func bestCandidate(fromSrcset srcset: String) -> String? {
        let candidates = srcset
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        var bestURL: String?
        var bestWeight: Double = -1

        for candidate in candidates {
            let parts = candidate.split(separator: " ", maxSplits: 1).map(String.init)
            guard
                let url = parts.first
            else {
                continue
            }
            let weight = parts.count == 2 ? parseWeight(parts[1]) : 1.0
            if weight > bestWeight {
                bestWeight = weight
                bestURL = url
            }
        }

        return bestURL
    }

    private static func parseWeight(_ raw: String) -> Double {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix("w") {
            return Double(trimmed.dropLast()) ?? 0
        }
        if trimmed.hasSuffix("x") {
            // Density descriptor — multiply by a baseline so a 2x reads larger than a 1500w.
            // But that's not really fair; treat as small additive bias instead.
            return Double(trimmed.dropLast()) ?? 0
        }
        return 0
    }
}
