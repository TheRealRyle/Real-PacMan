import Foundation

struct ParcoursCandidate: Identifiable {
    let id: UUID
    let name: String
    let description: String
    let route: GameRoute?
}
