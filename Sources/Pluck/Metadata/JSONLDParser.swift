import Foundation
import Rosetta
import SwiftSoup


// MARK: - JSONLDParser

/// Walks all `<script type="application/ld+json">` blocks and assembles a
/// `SchemaOrgData` keyed by `@type`. Handles single objects, top-level arrays,
/// and `@graph` containers. Multiple entries with the same `@type` are kept
/// as an array under that key.
enum JSONLDParser {

    static func parse(_ document: SwiftSoup.Document) -> SchemaOrgData? {
        guard
            let scripts = try? document.select("script[type=application/ld+json]")
        else {
            return nil
        }

        var byType: [String: [JSONValue]] = [:]
        for script in scripts.array() {
            guard
                let raw = try? script.data()
            else {
                continue
            }
            for entity in entities(fromRawJSON: raw) {
                guard
                    case .object(let object) = entity,
                    let typeValue = object["@type"]
                else {
                    continue
                }
                for typeName in typeNames(from: typeValue) {
                    byType[typeName, default: []].append(entity)
                }
            }
        }

        guard
            !byType.isEmpty
        else {
            return nil
        }

        var data: [String: JSONValue] = [:]
        for (key, values) in byType {
            data[key] = values.count == 1 ? values[0] : .array(values)
        }
        return SchemaOrgData(data: data)
    }


    // MARK: - JSON parsing

    private static func entities(fromRawJSON raw: String) -> [JSONValue] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let data = trimmed.data(using: .utf8),
            let parsed = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        else {
            return []
        }
        let value = jsonValue(from: parsed)

        switch value {
        case .array(let items):
            return items.flatMap(flatten)

        case .object:
            return flatten(value)

        default:
            return []
        }
    }

    /// Pulls out the inner objects when an entry uses `@graph`.
    private static func flatten(_ value: JSONValue) -> [JSONValue] {
        guard
            case .object(let object) = value
        else {
            return []
        }
        if case .array(let graph) = object["@graph"] ?? .null {
            return graph.flatMap(flatten)
        }
        return [value]
    }

    private static func typeNames(from value: JSONValue) -> [String] {
        switch value {
        case .string(let name):
            return [name]

        case .array(let items):
            return items.compactMap {
                if case .string(let name) = $0 {
                    return name
                }
                return nil
            }

        default:
            return []
        }
    }

    static func jsonValue(from any: Any) -> JSONValue {
        if any is NSNull {
            return .null
        }
        if let bool = any as? Bool, type(of: any) == type(of: NSNumber(value: true)) {
            // NSNumber boxing: a real Bool boxes as __NSCFBoolean. Distinguish
            // before falling through to the numeric branch.
            return .bool(bool)
        }
        if let number = any as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }
            return .number(number.doubleValue)
        }
        if let string = any as? String {
            return .string(string)
        }
        if let array = any as? [Any] {
            return .array(array.map(jsonValue(from:)))
        }
        if let dict = any as? [String: Any] {
            var object: [String: JSONValue] = [:]
            for (key, value) in dict {
                object[key] = jsonValue(from: value)
            }
            return .object(object)
        }
        return .null
    }
}
