import Foundation
import Observation
import Security

struct PlayerIdentity: Codable, Equatable {
    let id: UUID
    let username: String
}
struct PlayerLogin: Codable {
    let player: PlayerIdentity
    let token: String
    let expiresAt: Date
}
struct SavedPlayerLogin: Codable {
    let server: String
    let login: PlayerLogin
}

@MainActor @Observable
final class PlayerAccount {
    private(set) var saved: SavedPlayerLogin?
    private(set) var isBusy = false
    var message: String?
    private let persistsSession: Bool
    private let keychainKey = "realpacman.player-session.v1"
    var player: PlayerIdentity? {
        guard let saved, saved.login.expiresAt > Date() else { return nil }
        return saved.login.player
    }
    init(persistsSession: Bool = true) {
        self.persistsSession = persistsSession
        guard persistsSession else { return }
        var item: CFTypeRef?
        var query = keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data {
            saved = try? JSONDecoder().decode(SavedPlayerLogin.self, from: data)
        }
    }
    private var keychainQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: keychainKey,
         kSecAttrAccount as String: "current-player"]
    }
    func credentials(for server: String) -> PlayerLogin? {
        guard let saved, saved.server == Self.normalized(server), saved.login.expiresAt > Date() else { return nil }
        return saved.login
    }
    static func normalized(_ server: String) -> String {
        var value = server.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") { value.removeLast() }
        return value
    }
    func signIn(server: String, username: String, password: String, register: Bool) async -> Bool {
        guard !isBusy else { return false }
        message = nil
        if register {
            let name = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard name.range(of: "^[a-z0-9_]{3,24}$", options: .regularExpression) != nil else {
                message = "Choose a username with 3–24 letters, numbers or underscores. Spaces aren’t allowed."
                return false
            }
            guard password.count >= 10 else {
                message = "Your password needs at least 10 characters."
                return false
            }
            guard password.utf8.count <= 72 else {
                message = "That password is too long. Try a shorter one."
                return false
            }
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let base = Self.normalized(server)
            var request = URLRequest(url: try ServerEndpoint.url(base, path: "auth/\(register ? "register" : "login")"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["username": username, "password": password])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let reason = (try? JSONDecoder().decode(APIError.self, from: data).reason) ?? "Sign-in failed. Check your connection and try again."
                throw NSError(domain: "PlayerAccount", code: 1, userInfo: [NSLocalizedDescriptionKey: reason])
            }
            let login = try JSONDecoder().decode(PlayerLogin.self, from: data)
            let session = SavedPlayerLogin(server: base, login: login)
            let encoded = try JSONEncoder().encode(session)
            var query = keychainQuery
            query[kSecValueData as String] = encoded
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let status = persistsSession ? SecItemUpdate(keychainQuery as CFDictionary,
                                       [kSecValueData as String: encoded] as CFDictionary) : errSecSuccess
            guard status == errSecSuccess || (status == errSecItemNotFound && SecItemAdd(query as CFDictionary, nil) == errSecSuccess) else {
                throw NSError(domain: "PlayerAccount", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not securely save your sign-in. Please try again."])
            }
            saved = session
            return true
        } catch { message = error.localizedDescription; return false }
    }
    func signOut() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        let session = saved
        saved = nil
        if persistsSession { SecItemDelete(keychainQuery as CFDictionary) }
        if let session, let url = try? ServerEndpoint.url(session.server, path: "auth/logout") {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(session.login.token)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: request)
        }
    }
    private struct APIError: Decodable { let reason: String }
}
