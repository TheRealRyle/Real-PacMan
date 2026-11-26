import SwiftUI

struct PlayerAccountView: View {
    @Environment(GameStore.self) private var game
    @Environment(GameSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var username = ""
    @State private var password = ""
    @State private var register = false
    @State private var failures = 0

    var body: some View {
        ArcadePage(title: "PLAYER ACCOUNT", symbol: "person.crop.circle.fill") {
            if let player = game.account.player {
                ArcadePanel(title: "SIGNED IN") {
                    Label(player.username, systemImage: "person.fill").font(.title2.bold())
                    Text("New walks belong to this player. Other players’ saved walks stay with their accounts.")
                        .font(.subheadline)
                    if game.account.credentials(for: settings.serverURL) == nil {
                        Text("This sign-in belongs to a different server. Sign out to connect to the selected server.")
                    } else {
                        Button("UPLOAD MY SAVED GUEST WALKS", systemImage: "icloud.and.arrow.up") {
                            game.claimGuestResults(server: settings.serverURL)
                            Task { await game.sync(server: settings.serverURL) }
                        }.buttonStyle(ArcadeButtonStyle(color: .green))
                        Text("This assigns unsynced guest walks on this device to \(player.username).")
                            .font(.caption)
                        Button("SYNC MY RESULTS", systemImage: "arrow.triangle.2.circlepath") {
                            Task { await game.sync(server: settings.serverURL) }
                        }.buttonStyle(ArcadeButtonStyle(color: .cyan))
                        .disabled(game.isSyncing)
                    }
                    Button("SIGN OUT", systemImage: "rectangle.portrait.and.arrow.right") {
                        Task { await game.account.signOut() }
                    }.buttonStyle(ArcadeButtonStyle(color: .yellow))
                    .disabled(game.account.isBusy)
                }
            } else {
                ArcadePanel(title: register ? "CREATE PLAYER" : "WELCOME BACK") {
                    TextField("Username", text: $username)
                        .textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(register ? .newPassword : .password)
                        .padding(12)
                        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
                        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(game.account.message == nil ? .white.opacity(0.3) : .red, lineWidth: 2) }
                        .phaseAnimator([0.0, -10, 10, -6, 6, -3, 0], trigger: failures) { content, offset in
                            content.offset(x: reduceMotion ? 0 : offset)
                        } animation: { _ in .linear(duration: 0.06) }
                    if register {
                        Text("Username: 3–24 letters, numbers or underscores. Password: 10–72 bytes. Keep it safe: password recovery isn’t available for this class project.")
                            .font(.caption)
                    }
                    if let message = game.account.message { Text(message).foregroundStyle(.red).font(.subheadline) }
                    Button {
                        Task {
                            if await game.account.signIn(server: settings.serverURL, username: username, password: password, register: register) {
                                password = ""
                                await game.sync(server: settings.serverURL)
                            } else { failures += 1 }
                        }
                    } label: {
                        Label(game.account.isBusy ? "CONNECTING…" : register ? "CREATE ACCOUNT" : "SIGN IN", systemImage: "person.badge.key.fill")
                            .frame(maxWidth: .infinity)
                    }.buttonStyle(ArcadeButtonStyle(color: .green))
                    .disabled(game.account.isBusy || username.isEmpty || password.isEmpty)
                    Button(register ? "ALREADY A PLAYER? SIGN IN" : "NEW PLAYER? CREATE ACCOUNT") {
                        register.toggle(); game.account.message = nil; password = ""
                    }.buttonStyle(ArcadeButtonStyle(color: .cyan)).disabled(game.account.isBusy)
                    Text("You can play offline without signing in. Guest walks stay on this device until you choose to upload them.")
                        .font(.caption)
                }
            }
        }
    }
}
