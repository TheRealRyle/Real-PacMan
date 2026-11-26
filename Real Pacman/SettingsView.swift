import SwiftUI

struct SettingsView: View {
    @Environment(GameSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        ArcadePage(title: "SETTINGS", symbol: "gearshape.fill") {
            ArcadeNavigationLink { PlayerAccountView() } label: {
                Label("PLAYER ACCOUNT", systemImage: "person.crop.circle.fill").frame(maxWidth: .infinity)
            }.buttonStyle(ArcadeButtonStyle(color: .yellow))
            ArcadePanel(title: "SOUND & FEEL") {
                volumeControl("Music", symbol: "music.note", value: $settings.musicVolume)
                volumeControl("Sound", symbol: "speaker.wave.2.fill", value: $settings.soundVolume)
                Divider().overlay(.white.opacity(0.3))
                Toggle(isOn: $settings.vibrationEnabled) {
                    Label("Vibration", systemImage: "iphone.radiowaves.left.and.right")
                }
                .tint(.green)
                .onChange(of: settings.vibrationEnabled) { ArcadeAudio.shared.play(.toggle) }
                Text("Music and sound volumes update live. Vibration effects are planned.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .arcadeEntrance(delay: 0.12)

            ArcadePanel(title: "MAP ZOOM") {
                Text("Choose how close the map follows your player.").font(.subheadline)
                Slider(value: $settings.mapZoom, in: GameplayRules.zoomRange, step: 0.25) {
                    Text("Following zoom")
                }.tint(.yellow)
                HStack { Text("Wider"); Spacer(); Text("Medium"); Spacer(); Text("Closer") }
                    .font(.caption)
                Button("RESET TO MEDIUM") { settings.mapZoom = GameplayRules.defaultZoom }
                    .buttonStyle(ArcadeButtonStyle(color: .cyan))
                Text("Medium is the original zoom and the default. Pinch to explore; Follow restores your chosen zoom.")
                    .font(.caption).foregroundStyle(.white.opacity(0.8))
            }
            .arcadeEntrance(delay: 0.18)

            ArcadePanel(title: "CONNECTION", color: Color(red: 0.05, green: 0.3, blue: 0.5)) {
                Label("Route server", systemImage: "network")
                TextField("https://your-server.example", text: $settings.serverURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.body)
                    .padding(14)
                    .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.35), lineWidth: 2) }
                    .accessibilityLabel("Route server URL")
                Text("Your route server supplies levels and receives saved results.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                #if DEBUG && targetEnvironment(simulator)
                Button("Use local development server", systemImage: "desktopcomputer") {
                    settings.serverURL = "http://127.0.0.1:8080"
                }
                .buttonStyle(ArcadeButtonStyle(color: .cyan))
                Text("Run the server on this Mac, then refresh parcours in Play.")
                    .font(.caption).foregroundStyle(.white.opacity(0.8))
                #endif
            }
            .arcadeEntrance(delay: 0.22)
        }
    }

    private func volumeControl(_ name: String, symbol: String, value: Binding<Double>) -> some View {
        VStack(spacing: 10) {
            HStack {
                Label(name, systemImage: symbol)
                Spacer()
                Text(value.wrappedValue, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
                    .foregroundStyle(.yellow)
            }
            Slider(value: value, in: 0...1) { Text(name) } onEditingChanged: { editing in
                if !editing { ArcadeAudio.shared.play(.adjust) }
            }
                .tint(.yellow)
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(GameSettings())
}
