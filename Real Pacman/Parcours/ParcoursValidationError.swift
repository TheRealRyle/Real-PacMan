import Foundation

struct ParcoursValidationError: LocalizedError {
    let reason: String
    var errorDescription: String? { reason }
}
