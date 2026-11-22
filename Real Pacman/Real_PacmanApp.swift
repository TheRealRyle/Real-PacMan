//
//  Real_PacmanApp.swift
//  Real Pacman
//
//  Created by Cocks Kardeiz on 28/09/2026.
//

import SwiftUI
import MapLibre

@main
struct Real_PacmanApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var settings = GameSettings()
    @State private var game = GameStore()

    init() {
        let configuration = URLSessionConfiguration.default
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        configuration.httpAdditionalHeaders = ["User-Agent": "RealPacman/\(version) (iOS; coconut-factory.Real-Pacman)"]
        configuration.httpMaximumConnectionsPerHost = 4
        MLNNetworkConfiguration.sharedManager.sessionConfiguration = configuration
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(game)
                .onChange(of: scenePhase, initial: true) {
                    ArcadeAudio.shared.setVolumes(music: settings.musicVolume, sound: settings.soundVolume)
                    ArcadeAudio.shared.setActive(scenePhase == .active)
                }
                .onChange(of: settings.musicVolume) {
                    ArcadeAudio.shared.setVolumes(music: settings.musicVolume, sound: settings.soundVolume)
                }
                .onChange(of: settings.soundVolume) {
                    ArcadeAudio.shared.setVolumes(music: settings.musicVolume, sound: settings.soundVolume)
                }
        }
    }
}
