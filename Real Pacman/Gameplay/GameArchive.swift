import Foundation

struct GameArchive: Codable {
    var routes: [GameRoute] = []
    var activeSession: GameSession?
    var results: [GameSession] = []
}
