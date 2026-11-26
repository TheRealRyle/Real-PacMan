import Observation
import Foundation

@MainActor @Observable
final class GameSettings {
    static let defaultServerURL = "https://real-pacman-api-o256.onrender.com"
    var musicVolume: Double { didSet { UserDefaults.standard.set(musicVolume, forKey: "musicVolume") } }
    var soundVolume: Double { didSet { UserDefaults.standard.set(soundVolume, forKey: "soundVolume") } }
    var vibrationEnabled: Bool { didSet { UserDefaults.standard.set(vibrationEnabled, forKey: "vibrationEnabled") } }
    var mapZoom: Double { didSet { UserDefaults.standard.set(mapZoom, forKey: "mapZoom") } }
    var serverURL: String { didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") } }

    init() {
        let defaults = UserDefaults.standard
        let savedZoom = defaults.object(forKey: "mapZoom") as? Double ?? GameplayRules.defaultZoom
        mapZoom = savedZoom.isFinite ? min(19, max(16, savedZoom)) : GameplayRules.defaultZoom
        musicVolume = defaults.object(forKey: "musicVolume") as? Double ?? 1
        soundVolume = defaults.object(forKey: "soundVolume") as? Double ?? 1
        vibrationEnabled = defaults.object(forKey: "vibrationEnabled") as? Bool ?? true
        let savedServer = defaults.string(forKey: "serverURL")?.trimmingCharacters(in: .whitespacesAndNewlines)
        // Upgrade the previous empty/loopback setup while retaining custom servers.
        let usesLocalServer = savedServer.flatMap(URL.init(string:))?.host.map {
            ["localhost", "127.0.0.1", "::1", "[::1]"].contains($0.lowercased())
        } ?? false
        serverURL = savedServer == nil || savedServer?.isEmpty == true || usesLocalServer
            ? Self.defaultServerURL : savedServer!
    }
}
