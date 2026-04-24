import Foundation
import NiftyTemplate
import SwiftSoup


// MARK: - ImageExtractor

enum ImageExtractor {

    static func extract(
        fullDocument: SwiftSoup.Document,
        contentElement: SwiftSoup.Element,
        baseURL: URL,
        heroCandidate: URL?
    ) throws -> [ExtractedImage] {
        let images = try fullDocument.select("img").array()

        var seen: Set<String> = []
        var results: [ExtractedImage] = []

        for image in images {
            guard
                let absoluteURL = absoluteImageURL(from: image, baseURL: baseURL)
            else {
                continue
            }
            let key = absoluteURL.absoluteString
            if seen.contains(key) {
                continue
            }
            seen.insert(key)

            let score = ImageScorer.score(
                image: image,
                contentElement: contentElement,
                absoluteURL: absoluteURL,
                heroCandidate: heroCandidate
            )
            let dimensions = ImageScorer.readDimensions(from: image)
            let altText = (try? image.attr("alt"))?.nilIfEmpty

            results.append(
                ExtractedImage(
                    sourceURL: absoluteURL,
                    altText: altText,
                    width: dimensions?.width,
                    height: dimensions?.height,
                    relevanceScore: score.value,
                    context: score.context
                )
            )
        }

        return results.sorted { $0.relevanceScore > $1.relevanceScore }
    }


    // MARK: - URL helper

    private static func absoluteImageURL(from image: SwiftSoup.Element, baseURL: URL) -> URL? {
        let candidates: [String] = [
            (try? image.attr("src")) ?? "",
            (try? image.attr("data-src")) ?? "",
        ]
        for raw in candidates where !raw.isEmpty {
            if let url = URL(string: raw, relativeTo: baseURL)?.absoluteURL {
                return url
            }
        }
        return nil
    }
}


// MARK: - String helper

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
