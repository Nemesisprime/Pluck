import Foundation
import NiftyTemplate


// MARK: - SummarizeFilterStub

/// Stub for `summarize` — naive truncate at the requested length, with an
/// ellipsis suffix when shortened. Phase 6 replaces this with Foundation
/// Models-backed summarization.
struct SummarizeFilterStub: Filter {

    static let name = "summarize"

    static let defaultLength = 280

    func apply(value: TemplateValue, args: [TemplateValue]) throws -> TemplateValue {
        let text = value.renderedString
        let length = SummarizeFilterStub.requestedLength(from: args)

        if text.count <= length {
            return .string(text)
        }
        let prefix = text.prefix(length)
        return .string(prefix + "…")
    }


    // MARK: - Args

    private static func requestedLength(from args: [TemplateValue]) -> Int {
        guard
            let first = args.first
        else {
            return defaultLength
        }
        if case .number(let value) = first {
            return max(1, Int(value))
        }
        if case .string(let value) = first, let parsed = Int(value) {
            return max(1, parsed)
        }
        return defaultLength
    }
}
