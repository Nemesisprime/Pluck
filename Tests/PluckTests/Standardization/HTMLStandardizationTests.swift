import XCTest
import SwiftSoup
@testable import Pluck


// MARK: - HTMLStandardizationTests

final class HTMLStandardizationTests: XCTestCase {

    // MARK: - Cleanup

    func testCleanupRemovesScriptsAndStyles() throws {
        let element = try parseBody("""
        <p>Keep</p>
        <script>alert('x')</script>
        <style>.x{}</style>
        """)
        try HTMLStandardization.cleanup(element)
        XCTAssertFalse(try element.html().contains("script"))
        XCTAssertFalse(try element.html().contains("style"))
        XCTAssertTrue(try element.html().contains("Keep"))
    }

    func testCleanupRemovesTrackingPixels() throws {
        let element = try parseBody("""
        <img src="hero.jpg" width="800" height="400">
        <img src="pixel.gif" width="1" height="1">
        """)
        try HTMLStandardization.cleanup(element)
        let images = try element.select("img")
        XCTAssertEqual(images.size(), 1)
        XCTAssertEqual(try images.first()?.attr("src"), "hero.jpg")
    }

    func testCleanupRemovesComments() throws {
        let element = try parseBody("<p>before<!-- ad --> after</p>")
        try HTMLStandardization.cleanup(element)
        XCTAssertFalse(try element.html().contains("ad"))
    }


    // MARK: - srcset

    func testResolveSrcsetPicksLargestWidthDescriptor() throws {
        let element = try parseBody("""
        <img srcset="small.jpg 320w, medium.jpg 640w, big.jpg 1200w" src="fallback.jpg">
        """)
        try HTMLStandardization.resolveSrcset(in: element)
        let img = try XCTUnwrap(element.select("img").first())
        XCTAssertEqual(try img.attr("src"), "big.jpg")
        XCTAssertEqual(try img.attr("srcset"), "")
    }


    // MARK: - Absolutization

    func testAbsolutizeURLsRewritesRelativeHrefAndSrc() throws {
        let element = try parseBody("""
        <a href="/article">link</a>
        <img src="hero.jpg">
        """)
        let base = URL(string: "https://example.com/section/page.html")!
        try HTMLStandardization.absolutizeURLs(in: element, baseURL: base)

        XCTAssertEqual(try element.select("a").first()?.attr("href"), "https://example.com/article")
        XCTAssertEqual(try element.select("img").first()?.attr("src"), "https://example.com/section/hero.jpg")
    }


    // MARK: - Headings

    func testNormalizeHeadingsDemotesMultipleH1s() throws {
        let element = try parseBody("""
        <h1>One</h1>
        <p>x</p>
        <h1>Two</h1>
        """)
        try HTMLStandardization.normalizeHeadings(in: element)
        XCTAssertEqual(try element.select("h1").size(), 0)
        XCTAssertEqual(try element.select("h2").size(), 2)
    }

    func testNormalizeHeadingsLeavesSingleH1Alone() throws {
        let element = try parseBody("<h1>Only</h1><p>x</p>")
        try HTMLStandardization.normalizeHeadings(in: element)
        XCTAssertEqual(try element.select("h1").size(), 1)
    }
}


// MARK: - Helpers

private extension HTMLStandardizationTests {
    func parseBody(_ inner: String) throws -> SwiftSoup.Element {
        let document = try SwiftSoup.parse("<html><body>\(inner)</body></html>")
        return try XCTUnwrap(document.body())
    }
}
