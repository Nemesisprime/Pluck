import Foundation
import Rosetta
import SwiftSoup


// MARK: - ExtractionPipeline

public enum ExtractionPipeline {

    /// URL-input variant: fetches via `HTMLAcquisition`, then runs the synchronous pipeline.
    public static func extract(
        url: URL,
        selectedText: String? = nil,
        acquisition: HTMLAcquisition = HTMLAcquisition()
    ) async throws -> WebClipperExtractionResult {
        let acquired: AcquisitionResult
        do {
            acquired = try await acquisition.fetch(url: url)
        } catch let error as AcquisitionError {
            throw ExtractionError.acquisition(error)
        }

        return try extract(
            html: acquired.html,
            finalURL: acquired.finalURL,
            selectedText: selectedText
        )
    }

    /// HTML-input variant: for the Action Extension path, where iOS may hand us
    /// preprocessed HTML alongside the URL. All work is synchronous so the
    /// non-`Sendable` `SwiftSoup.Element` never crosses an actor boundary.
    public static func extract(
        html: String,
        finalURL: URL,
        selectedText: String? = nil
    ) throws -> WebClipperExtractionResult {
        guard
            let document = try? SwiftSoup.parse(html, finalURL.absoluteString)
        else {
            throw ExtractionError.parseFailed
        }

        let metadata = try MetadataExtractor.extract(document: document, finalURL: finalURL)
        let content = try ContentExtractor.extract(
            html: html,
            url: finalURL,
            fullDocument: document
        )
        let images = try ImageExtractor.extract(
            fullDocument: document,
            contentElement: content.contentElement,
            baseURL: finalURL,
            heroCandidate: metadata.mainImage
        )

        let (selectedTextMarkdown, selectedTextHTML) = ExtractionPipeline.normalizeSelection(selectedText)

        return WebClipperExtractionResult(
            contentMarkdown: content.contentMarkdown,
            contentHTML: content.contentHTML,
            fullHTML: html,
            wordCount: content.wordCount,
            title: metadata.title,
            description: metadata.description,
            author: metadata.author,
            siteName: metadata.siteName,
            domain: metadata.domain,
            sourceURL: finalURL,
            publishedDate: metadata.publishedDate,
            language: metadata.language,
            mainImage: metadata.mainImage,
            favicon: metadata.favicon,
            metaTags: metadata.metaTags,
            schemaOrgData: metadata.schemaOrgData,
            keywords: metadata.keywords,
            images: images,
            selectedTextMarkdown: selectedTextMarkdown,
            selectedTextHTML: selectedTextHTML,
            highlights: nil
        )
    }


    // MARK: - Selection normalization

    /// If the selection looks like HTML, render both the HTML and a Markdown copy.
    /// Otherwise treat as plain text and store on both fields.
    private static func normalizeSelection(_ selection: String?) -> (markdown: String?, html: String?) {
        guard
            let selection,
            !selection.isEmpty
        else {
            return (nil, nil)
        }

        if selection.contains("<") && selection.contains(">"),
           let markdown = try? HTMLToMarkdown.convert(selection) {
            return (markdown, selection)
        }
        return (selection, nil)
    }
}
