import XCTest
import Rosetta
@testable import Pluck


// MARK: - ClipperEngineTests

final class ClipperEngineTests: XCTestCase {

    // MARK: - Default-template fallback

    func testFallsBackToDefaultTemplateWhenNothingMatches() throws {
        let defaultTemplate = ObsidianTemplate(
            name: "Default",
            noteNameFormat: "{{title}}",
            triggers: [],
            noteContentFormat: "# {{title}}\n\n{{content}}\n\n---\nSource: {{url}}"
        )
        let engine = ClipperEngine(templates: [], defaultTemplate: defaultTemplate)
        let extraction = makeExtraction(title: "Hello", contentMarkdown: "Body.")

        let outcome = try engine.process(extraction: extraction)
        XCTAssertEqual(outcome.template.name, "Default")
        XCTAssertEqual(outcome.result.title, "Hello")
        XCTAssertTrue(outcome.result.body.contains("# Hello"))
        XCTAssertTrue(outcome.result.body.contains("Body."))
        XCTAssertTrue(outcome.result.body.contains("Source:"))
    }


    // MARK: - Trigger matching

    func testMatchesURLPrefixTemplateOverDefault() throws {
        let recipe = ObsidianTemplate(
            name: "Recipe",
            noteNameFormat: "Recipe: {{title}}",
            triggers: ["https://example.com/recipes/"],
            noteContentFormat: "Ingredients..."
        )
        let defaultTemplate = ObsidianTemplate(
            name: "Default",
            noteNameFormat: "{{title}}",
            triggers: [],
            noteContentFormat: "{{content}}"
        )
        let engine = ClipperEngine(
            templates: [recipe],
            defaultTemplate: defaultTemplate
        )
        let extraction = makeExtraction(
            title: "Pancakes",
            sourceURL: URL(string: "https://example.com/recipes/pancakes")!
        )

        let outcome = try engine.process(extraction: extraction)
        XCTAssertEqual(outcome.template.name, "Recipe")
        XCTAssertEqual(outcome.result.title, "Recipe: Pancakes")
    }


    // MARK: - Tag merge

    func testMergeDedupsCaseInsensitivelyPreservingOrder() {
        let merged = ClipperEngine.mergeTagSuggestions(
            templateSuggestions: ["Swift", "iOS"],
            extractionKeywords: ["swift", "macos", "IOS"]
        )
        XCTAssertEqual(merged, ["Swift", "iOS", "macos"])
    }

    func testMergeCapsAtTwentyEntries() {
        let template = (1...30).map { "tag\($0)" }
        let merged = ClipperEngine.mergeTagSuggestions(
            templateSuggestions: template,
            extractionKeywords: []
        )
        XCTAssertEqual(merged.count, 20)
        XCTAssertEqual(merged.first, "tag1")
        XCTAssertEqual(merged.last, "tag20")
    }

    func testMergeIgnoresEmptyAndWhitespaceEntries() {
        let merged = ClipperEngine.mergeTagSuggestions(
            templateSuggestions: ["", "   ", "swift"],
            extractionKeywords: ["", "go"]
        )
        XCTAssertEqual(merged, ["swift", "go"])
    }


    // MARK: - End-to-end with stub filter

    func testEvaluatesWithAtlasFilterStubInBody() throws {
        let template = ObsidianTemplate(
            name: "Linked",
            noteNameFormat: "{{title | atlas_link}}",
            triggers: [],
            noteContentFormat: "{{content}}"
        )
        let engine = ClipperEngine(templates: [], defaultTemplate: template)
        let extraction = makeExtraction(title: "My Note", contentMarkdown: "Body")

        let outcome = try engine.process(extraction: extraction)
        XCTAssertEqual(outcome.result.title, "[[My Note]]")
    }
}


// MARK: - Helpers

private extension ClipperEngineTests {

    func makeExtraction(
        title: String,
        contentMarkdown: String = "",
        sourceURL: URL = URL(string: "https://example.com/")!,
        keywords: [String] = []
    ) -> WebClipperExtractionResult {
        WebClipperExtractionResult(
            contentMarkdown: contentMarkdown,
            contentHTML: "<p>\(contentMarkdown)</p>",
            fullHTML: "<html><body><p>\(contentMarkdown)</p></body></html>",
            wordCount: contentMarkdown.split(separator: " ").count,
            title: title,
            domain: sourceURL.host ?? "",
            sourceURL: sourceURL,
            keywords: keywords
        )
    }
}
