import Foundation

enum ServerEndpoint {
    static func url(_ base: String, path: String) throws -> URL {
        guard let url = URL(string: base.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else {
            throw URLError(.badURL)
        }
        var allowed = url.scheme == "https"
        #if DEBUG
        // Local development only; release builds still require HTTPS for every host.
        if url.scheme == "http", ["localhost", "127.0.0.1", "[::1]", "::1"].contains(host.lowercased()) {
            allowed = true
        }
        #endif
        guard allowed else { throw URLError(.badURL) }
        return url.appending(path: "api/v1/\(path)")
    }
}
