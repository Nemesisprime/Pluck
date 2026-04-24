import Foundation
import Rosetta


// MARK: - AtlasFilterRegistry

/// Builds a `FilterRegistry` containing NiftyTemplate's standard 49 filters
/// plus the Atlas-specific `atlas_link`, `atlas_tag`, and `summarize` stubs.
///
/// The stubs are placeholders so templates that reference these filters can
/// still render during Phases 1–4 of the Atlas Web Clipper. Phases 5 and 6
/// replace them with real implementations.
public enum AtlasFilterRegistry {

    public static var standard: FilterRegistry {
        var registry = FilterRegistry.withStandardFilters()
        registry.register(AtlasLinkFilterStub())
        registry.register(AtlasTagFilterStub())
        registry.register(SummarizeFilterStub())
        return registry
    }
}
