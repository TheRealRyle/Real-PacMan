import Vapor

/// Preserves optional graph metadata without depending on Apple's CoreLocation on Linux.
enum JSONValue: Codable, Equatable, Sendable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let v = try? value.decode(Bool.self) { self = .bool(v) }
        else if let v = try? value.decode(Double.self) { self = .number(v) }
        else if let v = try? value.decode(String.self) { self = .string(v) }
        else if let v = try? value.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try value.decode([String: JSONValue].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .object(let v): try value.encode(v)
        case .array(let v): try value.encode(v)
        case .string(let v): try value.encode(v)
        case .number(let v): try value.encode(v)
        case .bool(let v): try value.encode(v)
        case .null: try value.encodeNil()
        }
    }
}

struct Coordinate: Codable, Equatable, Sendable {
    let latitude: Double
    let longitude: Double
}

struct PelletPayload: Codable, Equatable, Sendable {
    let id: UUID
    let coordinate: Coordinate
    let value: Int
    enum CodingKeys: String, CodingKey { case id, coordinate, value }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        coordinate = try values.decode(Coordinate.self, forKey: .coordinate)
        value = try values.decodeIfPresent(Int.self, forKey: .value) ?? 10
    }
}

struct RoutePayload: Content, Equatable, Sendable {
    let id: UUID
    let name: String
    let version: Int
    let coordinates: [Coordinate]
    let pellets: [PelletPayload]
    let mapStyleURL: String
    let parcours: JSONValue?
}

struct ResultPayload: Content, Sendable {
    let id: UUID
    let route: RoutePayload
    // Swift JSONEncoder's default date representation: seconds since 2001-01-01.
    let startedAt: Double
    let finishedAt: Double?
    let collectedPelletIDs: [UUID]
    let distanceMeters: Double
    let mode: String?
    let syncedAt: Double?
    var rules: ResultRules? = nil

    func canonicalJSON() throws -> String {
        let normalized = ResultPayload(id: id, route: route, startedAt: startedAt, finishedAt: finishedAt,
            collectedPelletIDs: collectedPelletIDs.sorted { $0.uuidString < $1.uuidString },
            distanceMeters: distanceMeters, mode: mode ?? "explore", syncedAt: nil,
            rules: rules?.canonicalized)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(normalized), as: UTF8.self)
    }
}

struct GhostPayload: Codable, Sendable {
    let id: Int
    let pathID: String
    let distanceAlongPath: Double
    let isReversed: Bool
    let coordinate: Coordinate
}

struct ResultRules: Codable, Sendable {
    let activeElapsed: Double
    let timeLimitSeconds: Double?
    let livesRemaining: Int
    let collisionCooldownUntil: Double
    let ghosts: [GhostPayload]
    let outcome: String?

    var canonicalized: ResultRules {
        ResultRules(activeElapsed: activeElapsed, timeLimitSeconds: timeLimitSeconds,
                    livesRemaining: livesRemaining, collisionCooldownUntil: collisionCooldownUntil,
                    ghosts: ghosts.sorted { $0.id < $1.id }, outcome: outcome)
    }
}

struct ResultReceipt: Content, Sendable {
    let id: UUID
    let score: Int
    let duplicate: Bool
}
