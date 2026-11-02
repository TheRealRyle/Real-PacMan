import Observation
import Foundation

@MainActor @Observable
final class GameSettings {
    var musicVolume: Double { didSet { UserDefaults.standard.set(musicVolume, forKey: "musicVolume") } }
    var soundVolume: Double { didSet { UserDefaults.standard.set(soundVolume, forKey: "soundVolume") } }
    var vibrationEnabled: Bool { didSet { UserDefaults.standard.set(vibrationEnabled, forKey: "vibrationEnabled") } }
    var serverURL: String { didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") } }

    init() {
        let defaults = UserDefaults.standard
        musicVolume = defaults.object(forKey: "musicVolume") as? Double ?? 1
        soundVolume = defaults.object(forKey: "soundVolume") as? Double ?? 1
        vibrationEnabled = defaults.object(forKey: "vibrationEnabled") as? Bool ?? true
        serverURL = defaults.string(forKey: "serverURL") ?? ""
    }
}
