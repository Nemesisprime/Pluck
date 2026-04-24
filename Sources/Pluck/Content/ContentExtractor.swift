import Foundation
import NiftyTemplate
import SwiftReadability
import SwiftSoup


// MARK: - ContentExtractor

enum ContentExtractor {

    static func extract(
        html: String,
        url: URL,
        fullDocument: SwiftSoup.Document
    ) throws -> ExtractedContent {
        let contentElement = try resolveContentElement(
            html: html,
            url: url,
            fullDocument: fullDocument
        )

        try HTMLStandardization.cleanup(contentElement)
        try HTMLStandardization.resolveSrcset(in: contentElement)
        try HTMLStandardization.absolutizeURLs(in: contentElement, baseURL: url)
        try HTMLStandardization.normalizeHeadings(in: contentElement)

        let contentHTML = try contentElement.html()
        let contentMarkdown = try HTMLToMarkdown.convert(contentHTML)
        let wordCount = ContentExtractor.countWords(in: contentMarkdown)

        return ExtractedContent(
            contentHTML: contentHTML,
            contentMarkdown: contentMarkdown,
            wordCount: wordCount,
            contentElement: contentElement
        )
    }


    // MARK: - Content selection

    private static func resolveContentElement(
        html: String,
        url: URL,
        fullDocument: SwiftSoup.Document
    ) throws -> SwiftSoup.Element {
        if let readabilityElement = try? readabilityElement(html: html, url: url) {
            return readabilityElement
        }
        return try fallbackElement(in: fullDocument)
    }

    private static func readabilityElement(html: String, url: URL) throws -> SwiftSoup.Element? {
        let reader = Readability(html: html, url: url)
        guard
            let result = try reader.parse(),
            !result.contentHTML.isEmpty
        else {
            return nil
        }
        let parsed = try SwiftSoup.parse(result.contentHTML, url.absoluteString)
        return try parsed.body() ?? parsed
    }

    /// Last-resort selection: walk the document for `<main>`, then `<article>`,
    /// then the `<div>` whose stripped text is longest.
    private static func fallbackElement(in document: SwiftSoup.Document) throws -> SwiftSoup.Element {
        for selector in ["main", "article"] {
            if let element = try document.select(selector).first() {
                return element
            }
        }

        var best: (element: SwiftSoup.Element, length: Int)?
        for div in try document.select("div").array() {
            let text = (try? div.text()) ?? ""
            let length = text.count
            if best == nil || length > best!.length {
                best = (div, length)
            }
        }
        if let best {
            return best.element
        }

        return try document.body() ?? document
    }


    // MARK: - Word count

    static func countWords(in markdown: String) -> Int {
        markdown
            .split(whereSeparator: { $0.isWhitespace })
            .filter { token in
                token.contains(where: { $0.isLetter || $0.isNumber })
            }
            .count
    }
}
