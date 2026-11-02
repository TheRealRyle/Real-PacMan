//
//  Real_PacmanApp.swift
//  Real Pacman
//
//  Created by Cocks Kardeiz on 28/09/2026.
//

import SwiftUI

@main
struct Real_PacmanApp: App {
    @State private var settings = GameSettings()
    @State private var game = GameStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(game)
        }
    }
}
