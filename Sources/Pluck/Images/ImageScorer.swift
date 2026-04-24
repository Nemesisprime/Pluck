import Foundation
import Rosetta
import SwiftSoup


// MARK: - ImageScorer

/// Stateless scorer that classifies a single `<img>` element into an
/// `ExtractedImage.ImageContext` with a relevance score. Pulled out of
/// `ImageExtractor` so the rules are testable in isolation.
enum ImageScorer {

    struct Score {
        let context: ExtractedImage.ImageContext
        let value: Float
    }

    static func score(
        image: SwiftSoup.Element,
        contentElement: SwiftSoup.Element,
        absoluteURL: URL,
        heroCandidate: URL?
    ) -> Score {
        if let heroCandidate, absoluteURL == heroCandidate {
            return Score(context: .heroImage, value: 1.0)
        }

        let inContent = isDescendant(of: contentElement, candidate: image)
        let inFigure = isInsideFigure(image)
        let inSidebar = isInsideSidebar(image)
        let dimensions = readDimensions(from: image)

        if inContent && inFigure {
            return Score(context: .figure, value: 0.85)
        }
        if inContent {
            return Score(context: .inlineContent, value: 0.7)
        }
        if inSidebar {
            return Score(context: .thumbnail, value: 0.1)
        }
        if let dimensions {
            if dimensions.width < 100 || dimensions.height < 100 {
                return Score(context: .thumbnail, value: 0.1)
            }
            if dimensions.width >= 400 && dimensions.height >= 400 {
                return Score(context: .outsideContent, value: 0.4)
            }
        }
        return Score(context: .outsideContent, value: 0.4)
    }


    // MARK: - Position helpers

    private static func isDescendant(of ancestor: SwiftSoup.Element, candidate: SwiftSoup.Element) -> Bool {
        var node: SwiftSoup.Element? = candidate
        while let current = node {
            if current === ancestor {
                return true
            }
            node = current.parent()
        }
        return false
    }

    private static func isInsideFigure(_ image: SwiftSoup.Element) -> Bool {
        var node: SwiftSoup.Element? = image.parent()
        while let current = node {
            if current.tagName().lowercased() == "figure" {
                return true
            }
            node = current.parent()
        }
        return false
    }

    private static func isInsideSidebar(_ image: SwiftSoup.Element) -> Bool {
        let sidebarTags: Set<String> = ["nav", "footer", "aside", "header"]
        var node: SwiftSoup.Element? = image.parent()
        while let current = node {
            if sidebarTags.contains(current.tagName().lowercased()) {
                return true
            }
            node = current.parent()
        }
        return false
    }


    // MARK: - Dimensions

    static func readDimensions(from image: SwiftSoup.Element) -> (width: Int, height: Int)? {
        let widthString = (try? image.attr("width")) ?? ""
        let heightString = (try? image.attr("height")) ?? ""
        guard
            let width = Int(widthString),
            let height = Int(heightString)
        else {
            return nil
        }
        return (width, height)
    }
}
