import XCTest
import SwiftSoup
@testable import Pluck


// MARK: - ContentExtractorTests

final class ContentExtractorTests: XCTestCase {

    // MARK: - Happy path

    func testExtractsArticleContentAndMarkdown() throws {
        let html = """
        <html><head><title>Cookies</title></head><body>
        <header><nav>Menu</nav></header>
        <main>
        <article>
        <h1>The Cookie Story</h1>
        <p>Cookies are tasty round treats baked from butter, sugar, and flour. \
        They originated as test cakes used by bakers to check oven temperatures \
        in the seventh century, and quickly became a beloved snack across many cultures. \
        Today they come in countless flavors and shapes, but the original chocolate-chip \
        recipe remains the most popular by a wide margin worldwide every single year.</p>
        <p>Recipes vary widely, but most follow a consistent ratio of fat, sugar, and flour. \
        The key to a great cookie is balancing crispness on the outside with chewiness inside. \
        Bakers achieve this through careful temperature control and the right ingredient ratios.</p>
        </article>
        </main>
        <footer>Copyright</footer>
        </body></html>
        """
        let document = try SwiftSoup.parse(html, "https://example.com/")
        let result = try ContentExtractor.extract(
            html: html,
            url: URL(string: "https://example.com/")!,
            fullDocument: document
        )

        XCTAssertFalse(result.contentMarkdown.isEmpty)
        XCTAssertGreaterThan(result.wordCount, 50)
        XCTAssertTrue(result.contentMarkdown.contains("Cookie"))
        XCTAssertFalse(result.contentMarkdown.contains("Copyright"), "Footer should not leak in")
    }


    // MARK: - Fallback path

    func testFallsBackToMainWhenReadabilityReturnsLittle() throws {
        let html = """
        <html><body>
        <main>
        <p>Short fallback content.</p>
        </main>
        </body></html>
        """
        let document = try SwiftSoup.parse(html, "https://example.com/")
        let result = try ContentExtractor.extract(
            html: html,
            url: URL(string: "https://example.com/")!,
            fullDocument: document
        )

        XCTAssertTrue(result.contentMarkdown.contains("fallback"))
    }


    // MARK: - Standardization integration

    func testRunsStandardizationOnExtractedContent() throws {
        let html = """
        <html><body>
        <article>
        <h1>One</h1>
        <h1>Two</h1>
        <p>Body. Body. Body. Body. Body. Body. Body. Body. Body. Body. \
        Body. Body. Body. Body. Body. Body. Body. Body. Body. Body. \
        Body. Body. Body. Body. Body. Body. Body. Body. Body. Body. \
        Body. Body. Body. Body. Body. Body. Body. Body. Body. Body.</p>
        <script>alert('x')</script>
        <img src="hero.jpg">
        </article>
        </body></html>
        """
        let url = URL(string: "https://example.com/section/")!
        let document = try SwiftSoup.parse(html, url.absoluteString)
        let result = try ContentExtractor.extract(
            html: html,
            url: url,
            fullDocument: document
        )

        XCTAssertFalse(result.contentHTML.contains("<script"))
        if result.contentHTML.contains("<img") {
            XCTAssertTrue(
                result.contentHTML.contains("https://example.com/section/hero.jpg"),
                "Image URLs should be absolutized"
            )
        }
    }


    // MARK: - Word count helper

    func testCountWordsIgnoresPureSymbolTokens() {
        XCTAssertEqual(ContentExtractor.countWords(in: "hello world"), 2)
        XCTAssertEqual(ContentExtractor.countWords(in: "hello — world"), 2)
        XCTAssertEqual(ContentExtractor.countWords(in: "  one\ttwo\nthree  "), 3)
    }
}
