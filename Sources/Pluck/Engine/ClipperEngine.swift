import Foundation
import Rosetta


// MARK: - ClipperEngine

/// Thin orchestrator over NiftyTemplate's `WebClipperEvaluator` and
/// `TemplateMatcher`. Holds the registered templates, runs the match against
/// the URL/schema, and merges tag suggestions from both the evaluator's
/// template-driven mappings and the extraction's raw keywords.
public struct ClipperEngine: Sendable {

    private let templates: [ObsidianTemplate]
    private let defaultTemplate: ObsidianTemplate
    private let evaluator: WebClipperEvaluator


    // MARK: - Init

    public init(
        templates: [ObsidianTemplate],
        defaultTemplate: ObsidianTemplate,
        registry: FilterRegistry = AtlasFilterRegistry.standard
    ) {
        self.templates = templates
        self.defaultTemplate = defaultTemplate
        self.evaluator = WebClipperEvaluator(engine: TemplateEngine(filters: registry))
    }


    // MARK: - Process

    public func process(
        extraction: WebClipperExtractionResult,
        selectedText: String? = nil
    ) throws -> ClipperOutcome {
        let (template, result) = try evaluator.matchAndEvaluate(
            templates: templates,
            defaultTemplate: defaultTemplate,
            extraction: extraction,
            selectedText: selectedText
        )

        let merged = ClipperEngine.mergeTagSuggestions(
            templateSuggestions: result.tagSuggestions,
            extractionKeywords: extraction.keywords
        )

        return ClipperOutcome(
            template: template,
            result: result,
            tagSuggestions: merged
        )
    }


    // MARK: - Tag merge

    /// Case-insensitive dedup of `result.tagSuggestions ∪ extraction.keywords`,
    /// preserving order (template-driven suggestions first), capped at 20.
    static func mergeTagSuggestions(
        templateSuggestions: [String],
        extractionKeywords: [String]
    ) -> [String] {
        var seen: Set<String> = []
        var merged: [String] = []
        for raw in templateSuggestions + extractionKeywords {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continue
            }
            let key = trimmed.lowercased()
            if seen.contains(key) {
                continue
            }
            seen.insert(key)
            merged.append(trimmed)
            if merged.count == 20 {
                break
            }
        }
        return merged
    }
}
