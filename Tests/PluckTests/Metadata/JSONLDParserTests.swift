import XCTest
import Rosetta
import SwiftSoup
@testable import Pluck


// MARK: - JSONLDParserTests

final class JSONLDParserTests: XCTestCase {

    func testParsesSingleArticleEntity() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {"@context":"https://schema.org","@type":"Article","headline":"Hello"}
        </script>
        </head><body></body></html>
        """
        let schema = try XCTUnwrap(parse(html))
        XCTAssertTrue(schema.hasType("Article"))
    }

    func testParsesArrayOfEntities() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        [
          {"@type":"Article","headline":"One"},
          {"@type":"Person","name":"Two"}
        ]
        </script>
        </head><body></body></html>
        """
        let schema = try XCTUnwrap(parse(html))
        XCTAssertTrue(schema.hasType("Article"))
        XCTAssertTrue(schema.hasType("Person"))
    }

    func testFlattensGraphContainer() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {"@context":"https://schema.org","@graph":[
          {"@type":"WebPage","name":"Page"},
          {"@type":"Recipe","name":"Pancakes"}
        ]}
        </script>
        </head><body></body></html>
        """
        let schema = try XCTUnwrap(parse(html))
        XCTAssertTrue(schema.hasType("WebPage"))
        XCTAssertTrue(schema.hasType("Recipe"))
    }

    func testMergesMultipleScriptBlocks() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">{"@type":"Article","headline":"A"}</script>
        <script type="application/ld+json">{"@type":"Person","name":"P"}</script>
        </head><body></body></html>
        """
        let schema = try XCTUnwrap(parse(html))
        XCTAssertTrue(schema.hasType("Article"))
        XCTAssertTrue(schema.hasType("Person"))
    }

    func testReturnsNilWhenNoLDBlocks() throws {
        let html = "<html><head></head><body></body></html>"
        XCTAssertNil(parse(html))
    }

    func testIgnoresMalformedJSON() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">not json</script>
        </head><body></body></html>
        """
        XCTAssertNil(parse(html))
    }

    func testTypeArrayIsRecorded() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {"@type":["Article","NewsArticle"],"headline":"H"}
        </script>
        </head><body></body></html>
        """
        let schema = try XCTUnwrap(parse(html))
        XCTAssertTrue(schema.hasType("Article"))
        XCTAssertTrue(schema.hasType("NewsArticle"))
    }
}


// MARK: - Helpers

private extension JSONLDParserTests {
    func parse(_ html: String) -> SchemaOrgData? {
        let document = try? SwiftSoup.parse(html)
        return document.flatMap(JSONLDParser.parse)
    }
}
