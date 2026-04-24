import XCTest
import Rosetta
@testable import Pluck


// MARK: - AtlasFilterRegistryTests

final class AtlasFilterRegistryTests: XCTestCase {

    // MARK: - Composition

    func testRegistersStandardFiltersPlusAtlasStubs() {
        let registry = AtlasFilterRegistry.standard
        let names = Set(registry.registeredNames)

        XCTAssertTrue(names.contains("atlas_link"))
        XCTAssertTrue(names.contains("atlas_tag"))
        XCTAssertTrue(names.contains("summarize"))
        XCTAssertTrue(names.contains("upper"), "Standard filters should still be present")
        XCTAssertTrue(names.contains("date"), "Standard filters should still be present")
    }


    // MARK: - Stub behaviour

    func testAtlasLinkWrapsInWikilinkBrackets() throws {
        let filter = try XCTUnwrap(AtlasFilterRegistry.standard.lookup(name: "atlas_link"))
        let result = try filter.apply(value: .string("My Note"), args: [])
        XCTAssertEqual(result, .string("[[My Note]]"))
    }

    func testAtlasTagKebabCasesAndPrefixes() throws {
        let filter = try XCTUnwrap(AtlasFilterRegistry.standard.lookup(name: "atlas_tag"))
        let result = try filter.apply(value: .string("Big Idea"), args: [])
        XCTAssertEqual(result, .string("#big-idea"))
    }

    func testSummarizePassesShortStringThrough() throws {
        let filter = try XCTUnwrap(AtlasFilterRegistry.standard.lookup(name: "summarize"))
        let result = try filter.apply(value: .string("Short."), args: [])
        XCTAssertEqual(result, .string("Short."))
    }

    func testSummarizeTruncatesWithEllipsisAtRequestedLength() throws {
        let filter = try XCTUnwrap(AtlasFilterRegistry.standard.lookup(name: "summarize"))
        let input = String(repeating: "x", count: 50)
        let result = try filter.apply(value: .string(input), args: [.number(10)])
        XCTAssertEqual(result, .string(String(repeating: "x", count: 10) + "…"))
    }


    // MARK: - End-to-end through TemplateEngine

    func testRendersTemplateUsingAtlasFilters() throws {
        let engine = TemplateEngine(filters: AtlasFilterRegistry.standard)
        let context = DictionaryContext([
            "title": .string("Hello World"),
            "topic": .string("My Topic"),
        ])
        let output = try engine.render("{{ title | atlas_link }} / {{ topic | atlas_tag }}", context: context)
        XCTAssertEqual(output, "[[Hello World]] / #my-topic")
    }
}
