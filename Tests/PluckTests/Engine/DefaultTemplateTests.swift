import XCTest
import NiftyTemplate
@testable import Pluck


// MARK: - DefaultTemplateTests

final class DefaultTemplateTests: XCTestCase {

    // MARK: - Loader

    func testLoadDecodesBundledTemplate() throws {
        let template = try DefaultTemplate.load()
        XCTAssertEqual(template.name, "Default")
        XCTAssertEqual(template.behavior, .create)
        XCTAssertTrue(template.triggers.isEmpty, "Default template is the fallback — no triggers")
        XCTAssertEqual(template.noteNameFormat, "{{title}}")
        XCTAssertTrue(template.noteContentFormat.contains("{{content}}"))
        XCTAssertTrue(template.noteContentFormat.contains("Source:"))
    }

    func testDefaultTemplateCarriesAtlasExtensions() throws {
        let template = try DefaultTemplate.load()
        let atlas = try XCTUnwrap(template.atlas)
        XCTAssertEqual(atlas.synopsisFormat, "{{description}}")
        let mappings = try XCTUnwrap(atlas.tagMappings)
        XCTAssertEqual(mappings.first?.source, .metaKeywords)
    }


    // MARK: - End-to-end with ClipperEngine

    func testDefaultTemplateRendersThroughClipperEngine() throws {
        let template = try DefaultTemplate.load()
        let engine = ClipperEngine(templates: [], defaultTemplate: template)
        let extraction = WebClipperExtractionResult(
            contentMarkdown: "Body text.",
            contentHTML: "<p>Body text.</p>",
            fullHTML: "<html><body><p>Body text.</p></body></html>",
            wordCount: 2,
            title: "An Article",
            description: "A short summary.",
            author: "Jane Doe",
            domain: "example.com",
            sourceURL: URL(string: "https://example.com/article")!,
            keywords: ["swift", "ios"]
        )

        let outcome = try engine.process(extraction: extraction)
        XCTAssertEqual(outcome.result.title, "An Article")
        XCTAssertTrue(outcome.result.body.contains("# An Article"))
        XCTAssertTrue(outcome.result.body.contains("Body text."))
        XCTAssertTrue(outcome.result.body.contains("https://example.com/article"))
        XCTAssertEqual(outcome.result.synopsis, "A short summary.")
        XCTAssertTrue(outcome.tagSuggestions.contains("swift"))
        XCTAssertTrue(outcome.tagSuggestions.contains("ios"))
    }
}
