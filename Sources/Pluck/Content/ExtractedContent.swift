import Foundation
import SwiftSoup


// MARK: - ExtractedContent

/// Output of `ContentExtractor`. `contentElement` is retained so `ImageExtractor`
/// can score images by their position relative to the article body — it must
/// not cross actor boundaries (`SwiftSoup.Element` is not `Sendable`).
struct ExtractedContent {
    let contentHTML: String
    let contentMarkdown: String
    let wordCount: Int
    let contentElement: SwiftSoup.Element
}
