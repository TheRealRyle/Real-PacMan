import AVFAudio
import OSLog

/// App-lifetime audio owner. Players are prepared once, never created during a button animation.
@MainActor
final class ArcadeAudio: NSObject {
    static let shared = ArcadeAudio()
    private let logger = Logger(subsystem: "RealPacman", category: "Audio")
    private var music: AVAudioPlayer?
    private var effects: [ArcadeSound: [AVAudioPlayer]] = [:]
    private var active = false
    private var interrupted = false
    private var gameplayVisible = false
    private var musicVolume: Float = 0
    private var soundVolume: Float = 0
    private var loaded = false

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(interruption),
                                              name: AVAudioSession.interruptionNotification, object: nil)
    }

    func setVolumes(music: Double, sound: Double) {
        musicVolume = Float(min(max(music, 0), 1))
        soundVolume = Float(min(max(sound, 0), 1))
        self.music?.volume = musicVolume * 0.65
        for players in effects.values {
            for player in players { player.volume = soundVolume * 0.8 }
        }
        updateMusic()
    }

    func setActive(_ value: Bool) {
        active = value
        if value {
            load()
            updateMusic()
        } else {
            music?.pause()
            for players in effects.values { for player in players { player.stop() } }
            do { try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
            catch { logger.error("Audio deactivation failed: \(error.localizedDescription)") }
        }
    }

    func setGameplayVisible(_ value: Bool) {
        gameplayVisible = value
        updateMusic()
    }

    func play(_ sound: ArcadeSound) {
        guard active, !interrupted, soundVolume > 0, let players = effects[sound] else { return }
        // A small voice pool lets rapid presses overlap without cutting off the previous chirp.
        guard let player = players.first(where: { !$0.isPlaying }) ?? players.first else { return }
        player.currentTime = 0
        player.volume = soundVolume * 0.8
        player.play()
    }

    private func load() {
        guard !loaded else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            music = try player(named: "menu_loop")
            music?.numberOfLoops = -1
            music?.volume = musicVolume * 0.65
            for sound in ArcadeSound.allCases {
                effects[sound] = try (0..<3).map { _ in try player(named: sound.rawValue) }
            }
            loaded = true
        } catch { logger.error("Audio setup failed: \(error.localizedDescription)") }
    }

    private func player(named name: String) throws -> AVAudioPlayer {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let player = try AVAudioPlayer(contentsOf: url)
        player.prepareToPlay()
        return player
    }

    private func updateMusic() {
        guard active, !interrupted else { music?.pause(); return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            if !gameplayVisible, musicVolume > 0 {
                if music?.isPlaying == false { music?.play() }
            } else { music?.pause() }
        } catch { logger.error("Audio activation failed: \(error.localizedDescription)") }
    }

    @objc private func interruption(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .began {
            interrupted = true
            music?.pause()
            for players in effects.values { for player in players { player.stop() } }
        } else {
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            interrupted = !AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume)
            updateMusic()
        }
    }
}
