import XCTest
import Rosetta
import SwiftSoup
@testable import Pluck


// MARK: - MetadataExtractorTests

final class MetadataExtractorTests: XCTestCase {

    // MARK: - Title resolution

    func testTitleResolvesFromOpenGraph() throws {
        let html = """
        <html><head>
        <meta property="og:title" content="From OG">
        <title>From Title Tag</title>
        </head><body><h1>From H1</h1></body></html>
        """
        let result = try parse(html)
        XCTAssertEqual(result.title, "From OG")
    }

    func testTitleFallsBackToTitleTagThenH1() throws {
        let titleHTML = "<html><head><title>From Title Tag</title></head><body><h1>From H1</h1></body></html>"
        XCTAssertEqual(try parse(titleHTML).title, "From Title Tag")

        let h1HTML = "<html><head></head><body><h1>From H1</h1></body></html>"
        XCTAssertEqual(try parse(h1HTML).title, "From H1")
    }


    // MARK: - Core fields

    func testExtractsCoreMetadata() throws {
        let html = """
        <html lang="en"><head>
        <meta property="og:title" content="An Article">
        <meta property="og:description" content="A summary.">
        <meta property="og:site_name" content="Example Times">
        <meta property="og:image" content="/img/hero.jpg">
        <meta property="article:published_time" content="2026-01-15T12:00:00Z">
        <meta name="author" content="Jane Doe">
        <meta name="keywords" content="swift, ios, web clipper">
        <link rel="icon" href="/favicon.ico">
        </head><body></body></html>
        """
        let result = try parse(html, url: URL(string: "https://example.com/articles/foo")!)

        XCTAssertEqual(result.title, "An Article")
        XCTAssertEqual(result.description, "A summary.")
        XCTAssertEqual(result.siteName, "Example Times")
        XCTAssertEqual(result.author, "Jane Doe")
        XCTAssertEqual(result.publishedDate, "2026-01-15T12:00:00Z")
        XCTAssertEqual(result.language, "en")
        XCTAssertEqual(result.domain, "example.com")
        XCTAssertEqual(result.keywords, ["swift", "ios", "web clipper"])
        XCTAssertEqual(result.mainImage?.absoluteString, "https://example.com/img/hero.jpg")
        XCTAssertEqual(result.favicon?.absoluteString, "https://example.com/favicon.ico")
    }

    func testFaviconDefaultsWhenLinkAbsent() throws {
        let html = "<html><head></head><body></body></html>"
        let result = try parse(html, url: URL(string: "https://example.com/path")!)
        XCTAssertEqual(result.favicon?.absoluteString, "https://example.com/favicon.ico")
    }


    // MARK: - Meta tags pass-through

    func testCollectsMetaTagsExposingNameAndProperty() throws {
        let html = """
        <html><head>
        <meta name="description" content="desc">
        <meta property="og:title" content="title">
        <meta charset="utf-8">
        </head><body></body></html>
        """
        let result = try parse(html)
        XCTAssertTrue(result.metaTags.contains { $0.name == "description" && $0.content == "desc" })
        XCTAssertTrue(result.metaTags.contains { $0.property == "og:title" && $0.content == "title" })
        // Bare <meta charset> has neither name nor property — should be skipped.
        XCTAssertFalse(result.metaTags.contains { $0.name == nil && $0.property == nil })
    }


    // MARK: - JSON-LD integration

    func testParsesJSONLDArticle() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {"@context":"https://schema.org","@type":"Article","headline":"Hello","author":{"@type":"Person","name":"Jane"}}
        </script>
        </head><body></body></html>
        """
        let result = try parse(html)
        let schema = try XCTUnwrap(result.schemaOrgData)
        XCTAssertTrue(schema.hasType("Article"))
    }
}


// MARK: - Helpers

private extension MetadataExtractorTests {
    func parse(_ html: String, url: URL = URL(string: "https://example.com/")!) throws -> ExtractedMetadata {
        let document = try SwiftSoup.parse(html, url.absoluteString)
        return try MetadataExtractor.extract(document: document, finalURL: url)
    }
}
