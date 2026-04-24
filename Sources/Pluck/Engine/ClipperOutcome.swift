import Foundation
import Rosetta


// MARK: - ClipperOutcome

/// Result of `ClipperEngine.process(...)` — the matched template, the
/// evaluated document, and the merged tag suggestions.
public struct ClipperOutcome: Sendable, Equatable {

    public let template: ObsidianTemplate
    public let result: WebClipperDocumentResult
    public let tagSuggestions: [String]


    // MARK: - Init

    public init(
        template: ObsidianTemplate,
        result: WebClipperDocumentResult,
        tagSuggestions: [String]
    ) {
        self.template = template
        self.result = result
        self.tagSuggestions = tagSuggestions
    }
}
