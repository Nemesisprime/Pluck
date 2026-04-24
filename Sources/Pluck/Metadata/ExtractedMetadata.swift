import Foundation
import NiftyTemplate


// MARK: - ExtractedMetadata

/// Aggregate of everything `MetadataExtractor` pulls off the page.
/// Pluck-internal — `ExtractionPipeline` unpacks it into `WebClipperExtractionResult`
/// at the boundary so each stage stays unit-testable in isolation.
struct ExtractedMetadata: Equatable {
    let title: String
    let description: String?
    let author: String?
    let siteName: String?
    let domain: String
    let publishedDate: String?
    let language: String?
    let mainImage: URL?
    let favicon: URL?
    let keywords: [String]
    let metaTags: [MetaTag]
    let schemaOrgData: SchemaOrgData?
}
