import SwiftUI

struct SettingsView: View {
    @Environment(GameSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Audio & feedback") {
                SliderSettingView(name: "Music", value: $settings.musicVolume)
                SliderSettingView(name: "Sound", value: $settings.soundVolume)
                Toggle("Vibration", isOn: $settings.vibrationEnabled)
                Text("Audio playback and vibration effects are planned.").font(.caption)
            }
            Section("Route server") {
                TextField("https://your-server.example", text: $settings.serverURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Text("Your Vapor server supplies routes and accepts saved results over HTTPS.")
                    .font(.caption)
            }
        }
        .navigationTitle("Settings")
    }
}
