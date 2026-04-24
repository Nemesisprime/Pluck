import Foundation


// MARK: - ExtractionError

public enum ExtractionError: Error, Equatable, Sendable {
    case parseFailed
    case acquisition(AcquisitionError)
}
