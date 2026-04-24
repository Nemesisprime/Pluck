import Foundation
import Rosetta
import SwiftSoup


// MARK: - MetadataExtractor

enum MetadataExtractor {

    static func extract(document: SwiftSoup.Document, finalURL: URL) throws -> ExtractedMetadata {
        let metaTags = collectMetaTags(in: document)
        let metaIndex = MetaIndex(metaTags)
        let schemaOrgData = JSONLDParser.parse(document)

        let title = resolveTitle(document: document, meta: metaIndex)
        let description = metaIndex.firstContent(forProperty: "og:description")
            ?? metaIndex.firstContent(forName: "description")
            ?? metaIndex.firstContent(forName: "twitter:description")
        let author = metaIndex.firstContent(forName: "author")
            ?? metaIndex.firstContent(forProperty: "article:author")
        let siteName = metaIndex.firstContent(forProperty: "og:site_name")
        let publishedDate = metaIndex.firstContent(forProperty: "article:published_time")
            ?? metaIndex.firstContent(forName: "date")
            ?? metaIndex.firstContent(forName: "pubdate")
        let language = (try? document.select("html").first()?.attr("lang"))?.nilIfEmpty
        let mainImage = (
            metaIndex.firstContent(forProperty: "og:image")
                ?? metaIndex.firstContent(forName: "twitter:image")
                ?? metaIndex.firstContent(forProperty: "twitter:image")
        ).flatMap { absoluteURL($0, base: finalURL) }
        let favicon = resolveFavicon(document: document, finalURL: finalURL)
        let keywords = (metaIndex.firstContent(forName: "keywords") ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return ExtractedMetadata(
            title: title,
            description: description?.nilIfEmpty,
            author: author?.nilIfEmpty,
            siteName: siteName?.nilIfEmpty,
            domain: finalURL.host ?? "",
            publishedDate: publishedDate?.nilIfEmpty,
            language: language,
            mainImage: mainImage,
            favicon: favicon,
            keywords: keywords,
            metaTags: metaTags,
            schemaOrgData: schemaOrgData
        )
    }


    // MARK: - Meta tags

    private static func collectMetaTags(in document: SwiftSoup.Document) -> [MetaTag] {
        guard
            let elements = try? document.select("meta")
        else {
            return []
        }
        var result: [MetaTag] = []
        for element in elements.array() {
            let name = (try? element.attr("name"))?.nilIfEmpty
            let property = (try? element.attr("property"))?.nilIfEmpty
            let content = (try? element.attr("content")) ?? ""
            if (name == nil && property == nil) || content.isEmpty {
                continue
            }
            result.append(MetaTag(name: name, property: property, content: content))
        }
        return result
    }


    // MARK: - Title resolution

    private static func resolveTitle(document: SwiftSoup.Document, meta: MetaIndex) -> String {
        if let og = meta.firstContent(forProperty: "og:title")?.nilIfEmpty {
            return og
        }
        if let twitter = meta.firstContent(forName: "twitter:title")?.nilIfEmpty {
            return twitter
        }
        if let title = (try? document.title())?.nilIfEmpty {
            return title
        }
        if let h1 = (try? document.select("h1").first()?.text())?.nilIfEmpty {
            return h1
        }
        return ""
    }


    // MARK: - Favicon

    private static func resolveFavicon(document: SwiftSoup.Document, finalURL: URL) -> URL? {
        let selectors = [
            "link[rel~=(?i)icon]",
            "link[rel~=(?i)shortcut icon]",
            "link[rel~=(?i)apple-touch-icon]",
        ]
        for selector in selectors {
            if let element = try? document.select(selector).first(),
               let href = (try? element.attr("href"))?.nilIfEmpty,
               let url = absoluteURL(href, base: finalURL) {
                return url
            }
        }
        return URL(string: "/favicon.ico", relativeTo: finalURL)?.absoluteURL
    }


    // MARK: - URL helpers

    private static func absoluteURL(_ raw: String, base: URL) -> URL? {
        guard
            let url = URL(string: raw, relativeTo: base)
        else {
            return nil
        }
        return url.absoluteURL
    }
}


// MARK: - MetaIndex

private struct MetaIndex {
    let byName: [String: [MetaTag]]
    let byProperty: [String: [MetaTag]]

    init(_ tags: [MetaTag]) {
        var byName: [String: [MetaTag]] = [:]
        var byProperty: [String: [MetaTag]] = [:]
        for tag in tags {
            if let name = tag.name?.lowercased() {
                byName[name, default: []].append(tag)
            }
            if let property = tag.property?.lowercased() {
                byProperty[property, default: []].append(tag)
            }
        }
        self.byName = byName
        self.byProperty = byProperty
    }

    func firstContent(forName name: String) -> String? {
        byName[name.lowercased()]?.first?.content
    }

    func firstContent(forProperty property: String) -> String? {
        byProperty[property.lowercased()]?.first?.content
    }
}


// MARK: - String helper

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
