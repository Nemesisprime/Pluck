import Foundation
import NiftyTemplate


// MARK: - DefaultTemplate

/// Loader for the bundled fallback template Atlas uses when no user-defined
/// template's triggers match. Backed by `Resources/Templates/default.json`,
/// imported through NiftyTemplate's `TemplateImporter` so the parsing rules
/// stay in one place.
public enum DefaultTemplate {

    public static func load() throws -> ObsidianTemplate {
        guard
            let url = Bundle.module.url(
                forResource: "default",
                withExtension: "json",
                subdirectory: nil
            )
        else {
            throw DefaultTemplateError.resourceNotFound
        }
        let data = try Data(contentsOf: url)
        return try TemplateImporter.importTemplate(from: data)
    }
}


// MARK: - DefaultTemplateError

public enum DefaultTemplateError: Error, Equatable, Sendable {
    case resourceNotFound
}
