//
//  Real_PacmanApp.swift
//  Real Pacman
//
//  Created by Cocks Kardeiz on 28/09/2026.
//

import SwiftUI

@main
struct Real_PacmanApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var settings = GameSettings()
    @State private var game = GameStore()
    
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
