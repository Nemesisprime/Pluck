import XCTest
import Rosetta
@testable import Pluck


// MARK: - ExtractionPipelineTests

final class ExtractionPipelineTests: XCTestCase {

    // MARK: - Per-fixture end-to-end

    func testEndToEndOnWikipediaFixture() throws {
        let result = try extractFixture(
            "wikipedia-style",
            url: URL(string: "https://en.wikipedia.org/wiki/Cookie")!
        )

        XCTAssertEqual(result.title, "Cookie")
        XCTAssertEqual(result.domain, "en.wikipedia.org")
        XCTAssertEqual(result.author, "Wikipedia contributors")
        XCTAssertEqual(result.siteName, "Wikipedia")
        XCTAssertGreaterThan(result.wordCount, 100)
        XCTAssertFalse(result.contentMarkdown.isEmpty)
        XCTAssertNotNil(result.mainImage)
        XCTAssertGreaterThan(result.metaTags.count, 0)
        XCTAssertTrue(result.images.contains { $0.context == .heroImage }, "Hero image should be detected")
    }

    func testEndToEndOnMDNFixture() throws {
        let result = try extractFixture(
            "mdn-style",
            url: URL(string: "https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/map")!
        )

        XCTAssertEqual(result.title, "Array.prototype.map()")
        XCTAssertEqual(result.domain, "developer.mozilla.org")
        XCTAssertEqual(result.siteName, "MDN Web Docs")
        XCTAssertGreaterThan(result.wordCount, 100)
        XCTAssertEqual(result.keywords, ["javascript", "array", "map", "mdn", "reference"])
        XCTAssertTrue(result.contentMarkdown.contains("map"))
    }

    func testEndToEndOnJSONLDNewsFixture() throws {
        let result = try extractFixture(
            "news-jsonld",
            url: URL(string: "https://daily-science.example/articles/mars-rover")!
        )

        XCTAssertEqual(result.title, "Mars Rover Sends Back New Images")
        XCTAssertEqual(result.author, "Sarah Chen")
        XCTAssertEqual(result.publishedDate, "2026-04-12T08:30:00Z")
        let schema = try XCTUnwrap(result.schemaOrgData)
        XCTAssertTrue(schema.hasType("NewsArticle"))
        XCTAssertTrue(schema.hasType("Organization"))
    }


    // MARK: - Selection handling

    func testPlainTextSelectionPopulatesMarkdownOnly() throws {
        let url = URL(string: "https://example.com/")!
        let result = try ExtractionPipeline.extract(
            html: "<html><body><p>Body</p></body></html>",
            finalURL: url,
            selectedText: "Just some text"
        )
        XCTAssertEqual(result.selectedTextMarkdown, "Just some text")
        XCTAssertNil(result.selectedTextHTML)
    }

    func testHTMLSelectionPopulatesBothFields() throws {
        let url = URL(string: "https://example.com/")!
        let result = try ExtractionPipeline.extract(
            html: "<html><body><p>Body</p></body></html>",
            finalURL: url,
            selectedText: "<p>Hello <strong>world</strong></p>"
        )
        XCTAssertEqual(result.selectedTextHTML, "<p>Hello <strong>world</strong></p>")
        let markdown = try XCTUnwrap(result.selectedTextMarkdown)
        XCTAssertTrue(markdown.contains("Hello"))
    }
}


// MARK: - Helpers

private extension ExtractionPipelineTests {

    func extractFixture(_ name: String, url: URL) throws -> WebClipperExtractionResult {
        let html = try loadFixture(name)
        return try ExtractionPipeline.extract(
            html: html,
            finalURL: url,
            selectedText: nil
        )
    }

    func loadFixture(_ name: String) throws -> String {
        guard
            let url = Bundle.module.url(forResource: name, withExtension: "html", subdirectory: "Fixtures")
        else {
            throw XCTSkip("Fixture \(name).html not found in test bundle")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
