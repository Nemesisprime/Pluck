import Foundation
import Rosetta


// MARK: - AtlasLinkFilterStub

/// Stub for `atlas_link` — wraps the input as an Obsidian-style `[[wikilink]]`.
/// Phase 5 replaces this with a real Atlas-document linker.
struct AtlasLinkFilterStub: Filter {

    static let name = "atlas_link"

    func apply(value: TemplateValue, args: [TemplateValue]) throws -> TemplateValue {
        let text = value.renderedString
        return .string("[[\(text)]]")
    }
}
