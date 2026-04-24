import Foundation
import NiftyTemplate


// MARK: - AtlasTagFilterStub

/// Stub for `atlas_tag` — emits a kebab-cased `#tag`. Phase 5 replaces this
/// with the Atlas tag-hierarchy resolver.
struct AtlasTagFilterStub: Filter {

    static let name = "atlas_tag"

    func apply(value: TemplateValue, args: [TemplateValue]) throws -> TemplateValue {
        let raw = value.renderedString
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        return .string("#\(raw)")
    }
}
