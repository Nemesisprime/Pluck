import XCTest
import NiftyTemplate
import SwiftSoup
@testable import Pluck


// MARK: - ImageExtractorTests

final class ImageExtractorTests: XCTestCase {

    // MARK: - Scoring & ordering

    func testHeroCandidateGetsTopScore() throws {
        let html = """
        <html><body>
        <main id="content">
            <article>
                <img src="hero.jpg">
                <p>Body</p>
                <img src="inline.jpg">
            </article>
        </main>
        <aside><img src="thumb.jpg" width="50" height="50"></aside>
        </body></html>
        """
        let result = try extractFrom(
            html: html,
            heroCandidate: URL(string: "https://example.com/hero.jpg")
        )

        XCTAssertEqual(result.first?.context, .heroImage)
        XCTAssertEqual(result.first?.sourceURL.absoluteString, "https://example.com/hero.jpg")
    }

    func testFigureContextWinsOverPlainInline() throws {
        let html = """
        <html><body>
        <main id="content">
            <figure><img src="figure.jpg"></figure>
            <p><img src="inline.jpg"></p>
        </main>
        </body></html>
        """
        let result = try extractFrom(html: html, heroCandidate: nil)
        let figure = result.first { $0.sourceURL.lastPathComponent == "figure.jpg" }
        let inline = result.first { $0.sourceURL.lastPathComponent == "inline.jpg" }

        XCTAssertEqual(figure?.context, .figure)
        XCTAssertEqual(inline?.context, .inlineContent)
        XCTAssertGreaterThan(figure?.relevanceScore ?? 0, inline?.relevanceScore ?? 0)
    }

    func testSidebarImagesScoreAsThumbnails() throws {
        let html = """
        <html><body>
        <main id="content"><p>Hi</p></main>
        <nav><img src="logo.png"></nav>
        <footer><img src="bug.png"></footer>
        </body></html>
        """
        let result = try extractFrom(html: html, heroCandidate: nil)
        XCTAssertTrue(result.allSatisfy { $0.context == .thumbnail })
    }


    // MARK: - URL handling

    func testRelativeURLsAreAbsolutized() throws {
        let html = """
        <html><body>
        <main id="content">
            <img src="/img/a.jpg">
            <img src="b.jpg">
        </main>
        </body></html>
        """
        let result = try extractFrom(
            html: html,
            heroCandidate: nil,
            baseURL: URL(string: "https://example.com/section/page")!
        )
        let urls = Set(result.map { $0.sourceURL.absoluteString })
        XCTAssertTrue(urls.contains("https://example.com/img/a.jpg"))
        XCTAssertTrue(urls.contains("https://example.com/section/b.jpg"))
    }

    func testDuplicateURLsAreDeduped() throws {
        let html = """
        <html><body>
        <main id="content">
            <img src="dup.jpg">
            <img src="dup.jpg">
        </main>
        </body></html>
        """
        let result = try extractFrom(html: html, heroCandidate: nil)
        XCTAssertEqual(result.count, 1)
    }


    // MARK: - Metadata pass-through

    func testCapturesAltAndDimensions() throws {
        let html = """
        <html><body>
        <main id="content">
            <img src="dog.jpg" alt="A good dog" width="640" height="480">
        </main>
        </body></html>
        """
        let result = try extractFrom(html: html, heroCandidate: nil)
        let dog = try XCTUnwrap(result.first)
        XCTAssertEqual(dog.altText, "A good dog")
        XCTAssertEqual(dog.width, 640)
        XCTAssertEqual(dog.height, 480)
    }
}


// MARK: - Helpers

private extension ImageExtractorTests {
    func extractFrom(
        html: String,
        heroCandidate: URL?,
        baseURL: URL = URL(string: "https://example.com/")!
    ) throws -> [ExtractedImage] {
        let document = try SwiftSoup.parse(html, baseURL.absoluteString)
        let contentElement = try document.select("#content").first()
            ?? document.body()
            ?? document
        return try ImageExtractor.extract(
            fullDocument: document,
            contentElement: contentElement,
            baseURL: baseURL,
            heroCandidate: heroCandidate
        )
    }
}
