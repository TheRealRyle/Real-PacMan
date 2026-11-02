import SwiftUI

struct SettingsView: View {
    @Environment(GameSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        ArcadePage(title: "SETTINGS", symbol: "gearshape.fill") {
            ArcadePanel(title: "SOUND & FEEL") {
                volumeControl("Music", symbol: "music.note", value: $settings.musicVolume)
                volumeControl("Sound", symbol: "speaker.wave.2.fill", value: $settings.soundVolume)
                Divider().overlay(.white.opacity(0.3))
                Toggle(isOn: $settings.vibrationEnabled) {
                    Label("Vibration", systemImage: "iphone.radiowaves.left.and.right")
                }
                .tint(.green)
                Text("Audio playback and vibration effects are planned.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .arcadeEntrance(delay: 0.12)

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
            Slider(value: value, in: 0...1) { Text(name) }
                .tint(.yellow)
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(GameSettings())
}
